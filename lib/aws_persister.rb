require 'securerandom'

class AWSPersister

  attr_writer :concurrency_mgr

  def initialize(opts={})
    required = [:ddb, :s3, :file_table_name, :archive_table_name, :bucket_name, :archive_prefix, :cover_art_prefix]
    missing = required.select { |key| opts[key].nil? }
    if not missing.empty?
      raise ArgumentError, "Missing options: #{missing}"
    end
    @opts = opts
    @file_table = nil
    @archive_table = nil
    @concurrency_mgr = nil
  end

  def init_file_table
    @file_table = @opts[:ddb].tables[@opts[:file_table_name]]
    @file_table.hash_key = [:local_file_path, :string]
    @file_table.range_key = [:local_dir, :string]
  end

  def init_archive_table
    @archive_table = @opts[:ddb].tables[@opts[:archive_table_name]]
    @archive_table.hash_key = [:local_dir, :string]
  end

  def fetch_media_file_item(file)
    if @file_table.nil?
      init_file_table
    end
    @file_table.items.at(File.absolute_path(file), File.dirname(File.absolute_path(file)))
  end

  def save_media_file(media_file)
    if @file_table.nil?
      init_file_table
    end
    tag_data = media_file.tag_data
    item = @file_table.items.create('local_file_path' =>File.absolute_path(media_file.file),
                               'local_dir' => File.dirname(File.absolute_path(media_file.file)))
    item.attributes.set(tag_data)
  end

  def write_cover_art(media_file)
    cover_art_data = media_file.cover_art
    object = @opts[:s3].buckets[@opts[:bucket_name]].objects["#{@opts[:cover_art_prefix]}#{SecureRandom.uuid}"]
    if @concurrency_mgr.nil?
      object.write(cover_art_data)
    else
      @concurrency_mgr.run_async {object.write(cover_art_data)}
    end
    item = fetch_media_file_item(media_file.file)
    item.attributes.set('cover_art_s3_object' => "s3://#{@opts[:bucket_name]}/#{object.key}")
    object.key
  end

  def write_archive(archive_parts=[])
    #upload parts to S3
    keys = []
    archive_parts.each do | part |
      key = "#{@opts[:archive_prefix]}#{File.basename(part)}"
      keys.push(key)
      File.open(part, 'r') do | file |
        if @concurrency_mgr.nil?
          @opts[:s3].buckets[@opts[:bucket_name]].objects[key].write(file)
        else
          @concurrency_mgr.run_async { @opts[:s3].buckets[@opts[:bucket_name]].objects[key].write(file) }
        end
      end
    end
    keys
  end

  def save_archive(local_dir, keys)
    if @archive_table.nil?
      init_archive_table
    end
    attributes = {
        'local_dir' => local_dir
    }
    i = 0
    keys.each do | key |
      i = i+1
      attributes["part#{i}"] = "s3://#{@opts[:bucket_name]}/#{key}"
    end
   @archive_table.items.create(attributes)
  end
end
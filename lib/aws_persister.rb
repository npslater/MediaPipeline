require 'securerandom'

class AWSPersister

  def initialize(opts={})
    required = [:ddb, :s3, :table_name, :bucket_name, :archive_prefix, :cover_art_prefix]
    missing = required.select { |key| opts[key].nil? }
    if not missing.empty?
      raise ArgumentError, "Missing options #{missing}"
    end
    @opts = opts
    @table = nil
  end

  def init_table
    @table = @opts[:ddb].tables[@opts[:table_name]]
    @table.hash_key = [:local_file_path, :string]
    @table.range_key = [:local_dir, :string]
  end

  def fetch_media_file_item(file)
    if @table.nil?
      init_table
    end
    item = @table.items.at(File.absolute_path(file), File.dirname(File.absolute_path(file)))
    item
  end

  def save_media_file(media_file)
    if @table.nil?
      init_table
    end
    tag_data = media_file.tag_data
    item = @table.items.create('local_file_path' =>File.absolute_path(media_file.file),
                               'local_dir' => File.dirname(File.absolute_path(media_file.file)))
    item.attributes.set(tag_data)
  end

  def write_cover_art(media_file)
    cover_art_data = media_file.cover_art
    object = @opts[:s3].buckets[@opts[:bucket_name]].objects["#{@opts[:cover_art_prefix]}#{SecureRandom.uuid}"]
    object.write(cover_art_data)
    item = fetch_media_file_item(media_file.file)
    item.attributes.set('cover_art_s3_object' => "s3://#{@opts[:bucket_name]}/#{object.key}")
    object
  end
end
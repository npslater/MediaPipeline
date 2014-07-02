require 'securerandom'
require 'uri'

module MediaPipeline
  class DataAccess

    attr_writer :concurrency_mgr
    attr_reader :context

    def initialize(data_access_context)
      @context = data_access_context
      @file_table = nil
      @archive_table = nil
      @concurrency_mgr = nil
    end

    def init_file_table
      @file_table = @context.ddb_opts[:ddb].tables[@context.ddb_opts[:file_table_name]]
      @file_table.hash_key = [:local_file_path, :string]
      @file_table.range_key = [:local_dir, :string]
    end

    def init_archive_table
      @archive_table = @context.ddb_opts[:ddb].tables[@context.ddb_opts[:archive_table_name]]
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
      object = @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects["#{@context.s3_opts[:cover_art_prefix]}#{SecureRandom.uuid}"]
      if @concurrency_mgr.nil?
        object.write(cover_art_data)
      else
        @concurrency_mgr.run_async {object.write(cover_art_data)}
      end
      item = fetch_media_file_item(media_file.file)
      item.attributes.set('cover_art_s3_object' => "s3://#{@context.s3_opts[:bucket_name]}/#{object.key}")
      object.key
    end

    def write_archive(archive_parts=[])
      #upload parts to S3
      keys = []
      archive_parts.each do | part |
        key = "#{@context.s3_opts[:archive_prefix]}#{File.basename(part)}"
        keys.push(key)
        File.open(part, 'r') do | file |
          if @concurrency_mgr.nil?
            @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key].write(file)
          else
            @concurrency_mgr.run_async { @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key].write(file) }
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
        attributes["part#{i}"] = "s3://#{@context.s3_opts[:bucket_name]}/#{key}"
      end
     @archive_table.items.create(attributes)
    end

    def queue_transcode_task(archive_key)
      message = JSON.generate({ archive_key: archive_key })
      queue =  @context.sqs_opts[:sqs].queues.named(@context.sqs_opts[:transcode_queue_name])
      queue.send_message(message)
      message
    end

    def fetch_archive_urls(archive_key)
      if @archive_table.nil?
        init_archive_table
      end
      item = @archive_table.items.at(archive_key)
      item.attributes.to_hash.select { |attr| attr.include?('part')}.values
    end

    def read_archive_object(url, download_dir)
      uri = URI(url)
      bucket = uri.host
      key = "#{File.basename(File.dirname(uri.path))}/#{File.basename(uri.path)}"
      file = "#{download_dir}/#{File.basename(key)}"
      object = @context.s3_opts[:s3].buckets[bucket].objects[key]
      File.open(file, 'wb') do | file |
        object.read do | chunk |
          file.write(chunk)
        end
      end
      file
    end

    def write_transcoder_input(input_files=[])
      keys = []
      input_files.each do | input |
        key = "#{@context.s3_opts[:transcode_input_prefix]}#{File.basename(input)}"
        keys.push(key)
        File.open(input, 'r') do | file |
          if @concurrency_mgr.nil?
            @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key].write(file)
          else
            @concurrency_mgr.run_async { @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key].write(file) }
          end
        end
      end
      keys
    end

    def save_transcode_info(archive_key, input_key, output_key)
      if @archive_table.nil?
        init_archive_table
      end
      if @file_table.nil?
        init_file_table
      end

    end
  end
end
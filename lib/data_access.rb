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
      object = @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[ObjectKeyUtils.cover_art_object_key(@context.s3_opts[:cover_art_prefix])]
      if @concurrency_mgr.nil?
        object.write(cover_art_data)
      else
        @concurrency_mgr.run_async {object.write(cover_art_data)}
      end
      item = fetch_media_file_item(media_file.file)
      item.attributes.set('cover_art_key' => object.key)
      object.key
    end

    def write_archive(archive_parts=[])
      #upload parts to S3
      keys = []
      archive_parts.each do | part |
        key = ObjectKeyUtils.archive_object_key(@context.s3_opts[:archive_prefix], File.basename(part))
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
        attributes["part#{i}"] = key
      end
     @archive_table.items.create(attributes)
    end

    def queue_transcode_task(archive_key)
      message = JSON.generate({ archive_key: archive_key })
      queue =  @context.sqs_opts[:sqs].queues.named(@context.sqs_opts[:transcode_queue_name])
      queue.send_message(message)
      message
    end

    def fetch_archive_part_keys(archive_key)
      if @archive_table.nil?
        init_archive_table
      end
      item = @archive_table.items.at(archive_key)
      item.attributes.to_hash.select { |attr| attr.include?('part')}.values
    end

    def read_archive_object(key, download_dir)
      file = "#{download_dir}/#{File.basename(key)}"
      object = @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key]
      File.open(file, 'wb') do | file |
        object.read do | chunk |
          file.write(chunk)
        end
      end
      file
    end

    def read_transcoder_output_object(key, download_dir)
      file = "#{download_dir}/#{File.basename(key)}"
      object = @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key]
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
        key = ObjectKeyUtils.file_object_key(@context.s3_opts[:transcode_input_prefix], File.basename(input))
        #key = "#{@context.s3_opts[:transcode_input_prefix]}#{File.basename(input)}"
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

    def write_tagged_output(tagged_file)
      key = ObjectKeyUtils.file_object_key(@context.s3_opts[:tagged_output_prefix], File.basename(tagged_file))
      object = @context.s3_opts[:s3].buckets[@context.s3_opts[:bucket_name]].objects[key]
      File.open(tagged_file, 'r') do | file |
        if @concurrency_mgr.nil?
          object.write(file)
        else
          @concurrency_mgr.run_async { object.write(file) }
        end
      end
      key
    end

    def find_media_file_item(index_name, key_conditions={})
      if @file_table.nil?
        init_file_table
      end
      @context.ddb_opts[:client].query(table_name: @context.ddb_opts[:file_table_name],
                                                    index_name: index_name,
                                                    key_conditions:key_conditions
      )

    end

    def find_media_file_item_by_input_key(transcode_input_key)
      response = find_media_file_item('idx_transcode_input_key',
                                      {
                                          'transcode_input_key' =>
                                              {
                                                  comparison_operator:'EQ',
                                                  attribute_value_list:[
                                                      {'s' => transcode_input_key}
                                                  ]
                                              }
                                      }
      )
      #puts response
      return fetch_media_file_item(response.data[:member].first['local_file_path'][:s])

    end

    def find_media_file_item_by_dir(archive_key, file)
      response = find_media_file_item('idx_local_dir',
                                     {
                                        'local_dir' =>
                                            {
                                                comparison_operator:'EQ',
                                                attribute_value_list:[
                                                    {'s' => archive_key}
                                                ]
                                            }
                                      }
      )
      response.data[:member].each do | result |
        #puts result
        if File.basename(result['local_file_path'][:s]).eql?(File.basename(file))
          return fetch_media_file_item(result['local_file_path'][:s])
        end
      end
      nil
    end

    def save_transcode_input_key(archive_key, input_key)
      item = find_media_file_item_by_dir(archive_key, File.basename(input_key))
      raise ArgumentError, "Unable to find matching database item for #{archive_key}, #{input_key}" if item.nil?
      item.attributes.set(transcode_input_key: input_key)
      item
    end

    def save_transcode_output_key(input_key, output_key)
      item = find_media_file_item_by_input_key(input_key)
      raise ArgumentError, "Unable to find matching database item for #{input_key}" if item.nil?
      item.attributes.set(transcode_output_key: output_key)
      item
    end

    def save_tagged_output_key(input_key, tagged_output_key)
      item = find_media_file_item_by_input_key(input_key)
      raise ArgumentError, "Unable to find matching database item for #{input_key}" if item.nil?
      item.attributes.set(tagged_output_key: tagged_output_key)
      item
    end
  end
end
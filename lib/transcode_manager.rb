require 'logger'
require 'taglib'
require 'securerandom'
require 'open3'

module MediaPipeline

  class TranscodeManager

    def initialize(data_access,
                   transcode_context,
                   archive_context,
                   logger:Logger.new(STDOUT))
      @logger = logger
      @data_access = data_access
      @context = transcode_context
      @archive_context = archive_context
    end

    def fetch_pipeline_id
      @context.transcoder.client.list_pipelines[:pipelines].each do | pipeline |
        if pipeline[:name].eql?(@context.pipeline_name)
          return pipeline[:id]
        end
      end
    end

    def create_job(input_key, output_key, output_key_prefix)
      @context.transcoder.client.create_job(
      {
          pipeline_id:fetch_pipeline_id,
          output_key_prefix:output_key_prefix,
          input:{
            key:input_key,
            container:'auto'
          },
          outputs: [
              {
                 key:output_key,
                 preset_id:@context.preset_id
              }
          ]
      }
    )
    end

    def transcode(archive_key)
      @logger.info(self.class) {LogMessage.new('transcode.begin', {key:archive_key}, 'Started processing files for transcode jobs').to_s}

      part_keys = @data_access.fetch_archive_part_keys(archive_key)
      @logger.info(self.class) { LogMessage.new('data_access.fetch_archive_urls', {key:archive_key,archive_parts:part_keys}, 'Fetched archive URLs from DynamoDB').to_s}

      dir = File.join(@archive_context.download_dir, SecureRandom.uuid)
      Dir.mkdir(dir)
      @logger.info(self.class) { LogMessage.new('extract_archive.create_dir', {directory:dir}, 'Created directory to extract archive').to_s }

      archive = nil
      part_keys.each do | part |
        file = @data_access.read_archive_object(part, dir)
        archive = file unless archive
        @logger.info(self.class) { LogMessage.new('data_access.read_archive_object', {part:part, directory:dir, file:file, file_size: File.size(file)},'Downloaded archive file from S3').to_s}
      end

      cmd = "#{@archive_context.rar_path} x #{archive}"
      @logger.info(self.class) { LogMessage.new('rar.extract', {command:cmd}, 'Extracting RAR archive').to_s}
      Dir.chdir(dir) do
        Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid
          @logger.debug(self.class) {LogMessage.new('process.start', {pid:pid}, 'Process started').to_s}

          ret = wait_thr.value
          errors = stderr.read

          @logger.debug(self.class) {LogMessage.new('process.end', {pid:pid, status:ret}, 'Process finished').to_s}
          if errors.length > 0
            @logger.error(self.class) { LogMessage.new('process.stderr', {errors:errors}, 'Process errors').to_s}
          end
        }
      end

      filter = "#{dir}/**/*.#{@context.input_ext}"
      files = Dir.glob(filter)
      keys = @data_access.write_transcoder_input(files)
      @logger.info(self.class) {LogMessage.new('data_access.write_transcoder_input', {files:files, total_size:files.map{|file| File.size(file)}.inject(0){|total, size| total+size}}, 'Wrote transcoder input files to S3').to_s}

      #wait for s3 uploads to complete
      bucket = @data_access.context.s3_opts[:s3].buckets[@data_access.context.s3_opts[:bucket_name]]
      finished = false
      while not finished
        uploaded = keys.select {|key| bucket.objects[key].exists?}.count
        @logger.debug(self.class) {LogMessage.new('wait.upload', {completed:uploaded, remaining:keys.count-uploaded, total:keys.count}, 'Waiting for S3 upload(s) to complete').to_s}
        finished = (uploaded == keys.count)
        sleep 5
      end

      #for each file, submit a job to the ElasticTranscoder pipeline
      i = 0
      keys.each do | key |
        out_key = ObjectKeyUtils.file_object_key('', "#{File.basename(key, @context.input_ext)}#{@context.output_ext}")
        #out_key = "#{File.basename(key, @context.input_ext)}#{@context.output_ext}"
        create_job(key, out_key, @data_access.context.s3_opts[:transcode_output_prefix])
        wait_time = [(i^2) * 0.010, 1].min
        sleep wait_time
        i = i+1
        @logger.info(self.class) {LogMessage.new('transcoder.submit_job', {input_key:key, output_key:out_key}, 'Submitted job to transcoding pipeline').to_s}

        item = @data_access.save_transcode_input_key(archive_key, key)
        @logger.info(self.class) {LogMessage.new('data_access.save_transcode_input_key', {item:item.hash_value, input_key:key}, 'Saved transcode input key to DynamoDB table item').to_s}

      end
      @logger.info(self.class) {LogMessage.new('transcode.end', {key:archive_key}, 'Finished processing files for transcode jobs').to_s}
    end

    def process_transcoder_output(input_key, output_key)
      @logger.info(self.class) {LogMessage.new('process_transcoder_output.start', {input_key:input_key, output_key:output_key}, 'Started processing transcoder output file').to_s}

      item = @data_access.save_transcode_output_key(input_key, output_key)
      @data_access.increment_stat(item.range_value, MediaPipeline::ProcessingStat.num_transcoded_files(1))
      @logger.info(self.class) {LogMessage.new('data_access.save_transcode_output_key', {item:item.hash_value, input_key:input_key, output_key:output_key}, 'Saved transcode output key to DynamoDB table item').to_s}

      tag_data = {
          'artist' => item.attributes['artist'],
          'album' => item.attributes['album'],
          'genre' => item.attributes['genre'],
          'title' => item.attributes['title'],
          'disk' => item.attributes['disk'].nil? ? 0 : item.attributes['disk'].to_i,
          'track' => item.attributes['track'].nil? ? 0 : item.attributes['track'].to_i,
          'year' => item.attributes['year'].nil? ? 0 : item.attributes['year'].to_i,
          'comments' => item.attributes['comments']
      }
      @logger.info(self.class) {LogMessage.new('process_transcoder_output.prepare_tag_data', {tag_data:tag_data}, 'Read tag data from database item').to_s}

      cover_art_key = item.attributes['cover_art_key']
      object = @data_access.context.s3_opts[:s3].buckets[@data_access.context.s3_opts[:bucket_name]].objects[cover_art_key]
      tag_data['cover_art'] = object.read
      @logger.info(self.class) {LogMessage.new('process_transcoder_output.read_cover_art', {cover_art_key:cover_art_key}, 'Read cover art from S3 object').to_s}

      file = @data_access.read_transcoder_output_object(output_key, @archive_context.download_dir)
      @data_access.increment_stat(item.range_value, MediaPipeline::ProcessingStat.size_bytes_transcoded_files(File.size(file)))
      @logger.info(self.class) {LogMessage.new('data_access.read_transcoder_output_object', {output_key:output_key, download_dir:@archive_context.download_dir}, 'Read transcoder output object from S3').to_s}

      media_file = MediaFile.new(file)
      media_file.write_tag(tag_data)
      @data_access.increment_stat(item.range_value, MediaPipeline::ProcessingStat.audio_length_transcoded_files(media_file.tag_data(false)[:length]))
      @logger.info(self.class) {LogMessage.new('media_file.write_tag', {file:file, file_size: File.size(file)}, 'Wrote ID3 tags').to_s}

      tagged_output_key = @data_access.write_tagged_output(media_file.file)
      @data_access.increment_stat(item.range_value, MediaPipeline::ProcessingStat.size_bytes_tagged_files(File.size(media_file.file)))
      @data_access.increment_stat(item.range_value, MediaPipeline::ProcessingStat.num_tagged_files(1))
      @logger.info(self.class) {LogMessage.new('data_access.write_tagged_output', {file:media_file.file, file_size: File.size(file), key:tagged_output_key}, 'Wrote tagged output file to S3').to_s}

      @data_access.save_tagged_output_key(input_key, tagged_output_key)
      @logger.info(self.class) {LogMessage.new('data_access.save_tagged_output_key', {item:item.hash_value, input_key: input_key, output_key:tagged_output_key}, 'Saved tagged output key to DynamoDB item').to_s}

      @logger.info(self.class) {LogMessage.new('process_transcoder_output.end', {input_key:input_key, output_key:output_key}, 'Finished processing transcoder output file').to_s}
    end
  end

end
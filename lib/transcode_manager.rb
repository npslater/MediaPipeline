require 'logger'
require 'TagLib'
require 'securerandom'
require 'open3'

module MediaPipeline

  class TranscodeManager

    def initialize(config, data_access, transcode_client, logger:Logger.new(STDOUT), file_extension:'m4a')
      @config = config
      @logger = logger
      @data_access = data_access
      @transcoder = transcode_client
      @file_extension = file_extension
    end

    def get_pipeline_id(response, pipeline_name)
      response[:pipelines].each do | pipeline |
        if pipeline[:name].eql?(pipeline_name)
          return pipeline[:id]
        end
      end
    end

    def create_job(pipeline_id, input_key, output_key, output_key_prefix, preset_id)
      @transcoder.create_job(
          {
            pipeline_id:pipeline_id,
            input:{
              key:input_key,
              frame_rate:auto,
              resolution:auto,
              aspect_ration:auto,
              interlaced:auto,
              container:auto
            },
            output: [{
             key:output_key,
             thumbnail_pattern:'',
             rotate:auto,
             preset_id:preset_id,
             watermarks:[],
             album_art:{},
             composition:[],
             captions:{},
             output_key_prefix:output_key_prefix,
             playlists:[]
            }]
          }
      )
    end

    def prepare_input(archive_key)

      urls = @data_access.fetch_archive_urls(archive_key)
      @logger.info(self.class) { LogMessage.new('data_access.fetch_archive_urls', {key:archive_key,urls:urls}, 'Fetched archive URLs from DynamoDB').to_s}

      dir = File.join(@config['local']['download_dir'], SecureRandom.uuid)
      Dir.mkdir(dir)
      @logger.info(self.class) { LogMessage.new('extract_archive.create_dir', {directory:dir}, 'Created directory to extract archive').to_s }

      archive = nil
      urls.each do | url |
        file = @data_access.read_archive_object(url, dir)
        archive = file unless archive
        @logger.info(self.class) { LogMessage.new('data_access.read_archive_object', {url:url, directory:dir, file:file},'Downloaded archive file from S3').to_s}
      end

      cmd = "#{@config['local']['rar_path']} x #{archive}"
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

      filter = "#{dir}/**/*.#{@file_extension}"
      files = Dir.glob(filter)
      keys = @data_access.write_transcoder_input(files)
      @logger.info(self.class) {LogMessage.new('data_access.write_transcoder_input', {files:files}, 'Wrote transcoder input files to S3').to_s}

      #for each file, submit a job to the ElasticTranscoder pipeline
      pipeline_id = get_pipeline_id(@transcoder.list_pipelines, @config['transcoder']['pipeline_name'])
      keys.each do | key |
        out_key = "#{File.basename(key, @file_extension)}.mp3" #TODO: parameterize this
        create_job(pipeline_id, key, out_key, @config['s3']['transcode_output_prefix'], @config['transcoder']['preset_id'])
        @logger.info(self.class) {LogMessage.new('transcoder.submit_job', {pipeline_id:pipeline_id, input_key:key, output_key:out_key}, 'Submitted job to transcoding pipeline').to_s}
      end
    end

    def tag_output

    end

  end

end
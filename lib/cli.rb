require 'thor'
require 'aws-sdk'
require 'json'

module MediaPipeline
  class CLI < Thor

    desc 'process-files', 'Processes the files in the given directory'
    long_desc <<-LONGDESC
      This command performs the following steps:

      1. Search for all the files in the directory specified with the --dir option that match the extension given by the --ext option.

      2. Group the files by their parent directories.

      3. For each file, extract the cover art and store it locally in the location specified by the local:cover_art_dir key in the config file.

      4. Upload each cover art file to the S3 bucket specified by the key s3:bucket in the config file.  The object name is the local file name prepended with the prefix specified by the s3:cover_art_prefix key in the config file.

      5. For each file, create a record in the DynamoDB table specified by the db:file_table key in the config file.  The hash key of the record is the local file path, and the attributes are the ID3 tags, and the s3 URL of the file's cover art.

      6. For each of the parent directories, create a RAR archive using the `rar` command specified by the local:rar_path key in the config file.

      7. Once each RAR archive is complete, upload the RAR archive pieces to the S3 bucket specified by the s3:bucket key in the config file.  The object name for each piece of the archive is the piece name (e.g "archive_1.rar, archive_2.rar, etc") prepended with the prefix specified by the s3:archive_prefix key in the config file.

      8. For each uploaded RAR archive, create a record in the DynamoDB table specified by the db:archive_table key in the config file.  The hash key of the record is the local directory path containing the files included in the archive, and the attributes are the S3 urls to each piece of the RAR archive.

      To make the S3 uploads more efficient, the number of concurrent uploads can be specified using the s3:concurrent_connections key in the config file.
    LONGDESC

    option :config, :required=>true, :banner=>'CONFIG FILE', :desc=>'The path to the config file'
    option :pipeline_name, :required=>true, :banner=>'NAME', :desc=>'The pipeline name'
    option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    option :verbose, :required=>false, :type=>:boolean, :desc=>'Verbose logging'
    option :dir, :required=>true, :banner=>'DIR', :desc=>'The directory containing the files to index'
    option :input_file_ext, :required=>true, :banner=>'EXT', :desc=>'The extension of the transcode input files to index'
    def process_files
      config = init_config(options[:config], options[:pipeline_name])
      data_access = init_data_access(config)

      logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(options[:log])
      logger.level = options[:verbose].nil? ? Logger::INFO : Logger::DEBUG

      concurrency_mgr = MediaPipeline::ConcurrencyManager.new(config['s3']['concurrent_connections'].to_i)
      concurrency_mgr.logger = logger
      data_access.concurrency_mgr=concurrency_mgr

      archive_context = init_archive_context(config)
      processor = MediaPipeline::FileProcessor.new(data_access,
                                                   archive_context,
                                                   logger:logger)

      dir_filter = MediaPipeline::DirectoryFilter.new(options[:dir], options[:input_file_ext])
      collection = MediaPipeline::MediaFileCollection.new

      dir_filter.filter.each do | file |
        collection.add_file(file)
      end

      scheduler = MediaPipeline::Scheduler.new(config['schedule']['hours_in_day'])
      collection.dirs.each do | k,v |
        begin
        if scheduler.can_execute?
          processor.process_files(k,v)
        end
        rescue => e
          logger.error(self.class) { MediaPipeline::LogMessage.new('process_files.error', {error:e.message}, 'Exception when running process-files command').to_s}
        end
      end
    end

    desc 'create', 'Create a media pipeline'
    option :config, :required=>true, :banner=>'CONFIG FILE', :desc=>'The path to the config file'
    option :pipeline_name, :required=>true, :banner=>'NAME', :desc=>'The pipeline name'
    option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    option :verbose, :required=>false, :type=>:boolean, :desc=>'Verbose logging'
    option :template, :required=>true, :banner=>'CFN_TEMPLATE', :desc=>'The path or URL to the CFN template'
    long_desc <<-LONGDESC
      Creates all the AWS resources required for the media pipeline.  Most resources are created using CloudFormation.

      The ElasticTranscoder pipeline is created using SDK calls.
    LONGDESC
    def create
      logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(options[:log])
      logger.level = options[:verbose].nil? ? Logger::INFO : Logger::DEBUG

      config = init_config(options[:config], options[:pipeline_name])
      builder = MediaPipeline::PipelineBuilder.new(MediaPipeline::PipelineContext.new(options[:pipeline_name],
                                                                                      options[:template],
                                                                                      AWS::CloudFormation.new(region:config['aws']['region']),
                                                                                      AWS::ElasticTranscoder.new(region:config['aws']['region']),
                                                                                      config['s3']['bucket'],
                                                                                      {
                                                                                          'S3BucketName' => config['s3']['bucket'],
                                                                                          'S3ArchivePrefix' => config['s3']['archive_prefix'],
                                                                                          'S3InputPrefix' => config['s3']['transcode_input_prefix'],
                                                                                          'S3OutputPrefix' => config['s3']['transcode_output_prefix'],
                                                                                          'S3CoverArtPrefix' => config['s3']['cover_art_prefix'],
                                                                                          'DDBFileTable' => config['db']['file_table'],
                                                                                          'DDBArchiveTable' => config['db']['archive_table'],
                                                                                          'TranscodeQueueName' => config['sqs']['transcode_queue'],
                                                                                          'ID3TagQueueName' => config['sqs']['id3tag_queue'],
                                                                                          'CloudPlayerUploadQueueName' => config['sqs']['cloudplayer_upload_queue'],
                                                                                          'TranscodeTopicName' => config['sns']['transcode_topic_name']
                                                                                      }),logger:logger)
      stack = builder.create_stack
      role_arn = stack.outputs.select {|output| output.key.eql?('TranscoderRole')}.first.value
      sns_arn = stack.outputs.select {|output| output.key.eql?('TranscodeSNSTopic')}.first.value
      builder.create_pipeline(role_arn, sns_arn)
    end

    desc 'delete', 'Delete a media pipeline'
    option :config, :required=>true, :banner=>'CONFIG FILE', :desc=>'The path to the config file'
    option :pipeline_name, :required=>true, :banner=>'NAME', :desc=>'The pipeline name'
    option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    option :verbose, :required=>false, :type=>:boolean, :desc=>'Verbose logging'
    option :delete_objects, :required=>false, :banner=>'REMOVES ALL OBJECTS IN S3 BUCKET'
    long_desc <<-LONGDESC
      Deletes all the AWS resources in a media pipeline.  THE --delete-objects OPTION WILL ALSO DELETE ALL OBJECTS IN THE PIPELINE'S S3 BUCKET!
      USE WITH CAUTION!
    LONGDESC
    def delete
      config = init_config(options[:config], options[:pipeline_name])

      response = ask("Delete pipeline #{options[:pipeline_name]}?  Are you sure (Y/n)?")
      if not response.eql?('Y')
        puts 'Delete aborted'
        exit 0
      end

      if options[:delete_objects]
        response = ask("Delete S3 objects in bucket #{config['s3']['bucket_name']}?  Are you sure (Y/n)")
        if not response.eql?('Y')
          puts 'Delete aborted'
          exit 0
        end
      end
      logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(options[:log])
      logger.level = options[:verbose].nil? ? Logger::INFO : Logger::DEBUG
      builder = MediaPipeline::PipelineBuilder.new(MediaPipeline::PipelineContext.new(options[:pipeline_name],
                                                                                      options[:template],
                                                                                      AWS::CloudFormation.new(region:config['aws']['region']),
                                                                                      AWS::ElasticTranscoder.new(region:config['aws']['region']),
                                                                                      config['s3']['bucket'],
                                                                                      {
                                                                                          'S3BucketName' => config['s3']['bucket'],
                                                                                          'S3ArchivePrefix' => config['s3']['archive_prefix'],
                                                                                          'S3InputPrefix' => config['s3']['transcode_input_prefix'],
                                                                                          'S3OutputPrefix' => config['s3']['transcode_output_prefix'],
                                                                                          'S3CoverArtPrefix' => config['s3']['cover_art_prefix'],
                                                                                          'DDBFileTable' => config['db']['file_table'],
                                                                                          'DDBArchiveTable' => config['db']['archive_table'],
                                                                                          'TranscodeQueueName' => config['sqs']['transcode_queue'],
                                                                                          'ID3TagQueueName' => config['sqs']['id3tag_queue'],
                                                                                          'CloudPlayerUploadQueueName' => config['sqs']['cloudplayer_upload_queue'],
                                                                                          'TranscodeTopicName' => config['sns']['transcode_topic_name']
                                                                                      }),logger:logger)
      begin
        s3 = AWS::S3.new(region:config['aws']['region'])
        builder.delete_stack(s3, options[:delete_objects])
      rescue => e
        logger.error(self.class) {MediaPipeline::LogMessage.new('delete.error', {error:e.message}, 'Error while deleting pipeline stack').to_s}
      end

      begin
        builder.delete_pipeline(options[:pipeline_name])
      rescue => e
        logger.error(self.class) {MediaPipeline::LogMessage.new('delete.error', {error:e.message}, 'Error while deleting pipeline').to_s}
      end
    end

    desc 'transcode', 'Poll for messages on the transcoding queue and submit jobs to the ElasticTranscoder pipeline'
    option :config, :required=>true, :banner=>'CONFIG FILE', :desc=>'The path to the config file'
    option :pipeline_name, :required=>true, :banner=>'NAME', :desc=>'The pipeline name'
    option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    option :verbose, :required=>false, :type=>:boolean, :desc=>'Verbose logging'
    option :poll_timeout, :required=>false, :banner=>'TIMEOUT', :type=>:numeric, :default=>3600, :desc=>'Stop polling after this interval if no messages are being received.'
    option :input_file_ext, :required=>true, :banner=>'INPUT_FILE_EXTENSION', :desc=>'The extension of the input files to be transcoded'
    long_desc <<-LONGDESC
      This command is designed to be run on the worker hosts that are responsible for downloading and unpacking an archive and
      submitting the files it contains to the ElasticTranscode pipeline.  The command will poll for messages on the transcode
      queue, download the archive specified in the message, upload the files in the archive to S3 and create an ElasticTranscoder job.

      The command uses long-polling and will poll for the length of time specified by the poll-timeout option (default 60 minutes).  The command will exit when
      no messages are being returned from the queue and the poll-timeout interval has been reached.
    LONGDESC
    def transcode
      logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(options[:log])
      logger.level = options[:verbose].nil? ? Logger::INFO : Logger::DEBUG

      config = init_config(options[:config], options[:pipeline_name])
      concurrency_mgr = MediaPipeline::ConcurrencyManager.new(config['s3']['concurrent_connections'])
      concurrency_mgr.logger = logger

      data_access = init_data_access(config)
      data_access.concurrency_mgr = concurrency_mgr

      context = MediaPipeline::TranscodingContext.new(AWS::ElasticTranscoder.new(region:config['aws']['region']),
                                            options[:pipeline_name],
                                            config['transcoder']['preset_id'],
                                            input_ext:options[:input_file_ext],
                                            output_ext:config['transcoder']['output_file_ext'])

      archive_context = MediaPipeline::ArchiveContext.new(config['local']['rar_path'], config['local']['archive_dir'], config['local']['download_dir'])
      transcode_mgr = MediaPipeline::TranscodeManager.new(data_access, context, archive_context, logger:logger)

      queue = data_access.context.sqs_opts[:sqs].queues.named(data_access.context.sqs_opts[:transcode_queue_name])
      logger.info(self.class) { MediaPipeline::LogMessage.new('transcode.poll_queue', {queue:queue.url, poll_timeout:options[:poll_timeout]}, 'Starting to poll for messages from SQS').to_s}

      begin
        queue.poll(idle_timeout:options[:poll_timeout], wait_time_seconds:20) do | msg |
          logger.info(self.class) { MediaPipeline::LogMessage.new('transcode.receive_message', {message:msg.body}, 'Received message from SQS queue').to_s}
          transcode_mgr.transcode(JSON.parse(msg.body)['archive_key'])
        end
      rescue => e
        logger.error(self.class) { MediaPipeline::LogMessage.new('transcode.error', {error:e.message}, 'Exception when running transcode command').to_s}
      end
    end

    desc 'process-output', 'Process the transcoded output files.  Write the ID3 tag to the files and upload the tagged files back to S3'
    long_desc <<-LONGDESC
      This command is designed to be run on the worker hosts responsible for processing the transcoded output files.  This command will poll
      for messages on the ID3 tag queue, download the transoded output files, and tag them using the data stored for each file item in DynamoDB.  In addition,
      the command will write the cover art to the file using the content stored in S3.

      The command uses long-polling and will poll for the length of time specified by the poll-timeout option (default 60 minutes).  The command will exit when
      no messages are being returned from the queue and the poll-timeout interval has been reached.
    LONGDESC
    option :config, :required=>true, :banner=>'CONFIG FILE', :desc=>'The path to the config file'
    option :pipeline_name, :required=>true, :banner=>'NAME', :desc=>'The pipeline name'
    option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    option :verbose, :required=>false, :type=>:boolean, :desc=>'Verbose logging'
    option :poll_timeout, :required=>false, :banner=>'TIMEOUT', :type=>:numeric, :default=>3600, :desc=>'Stop polling after this interval if no messages are being received.'
    def process_output
      logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(options[:log])
      logger.level = options[:verbose].nil? ? Logger::INFO : Logger::DEBUG

      config = init_config(options[:config], options[:pipeline_name])
      concurrency_mgr = MediaPipeline::ConcurrencyManager.new(config['s3']['concurrent_connections'])
      concurrency_mgr.logger = logger

      data_access = init_data_access(config)
      data_access.concurrency_mgr = concurrency_mgr

      context = MediaPipeline::TranscodingContext.new(AWS::ElasticTranscoder.new(region:config['aws']['region']),
                                                      options[:pipeline_name],
                                                      config['transcoder']['preset_id'],
                                                      input_ext:options[:input_file_ext],
                                                      output_ext:config['transcoder']['output_file_ext'])

      archive_context = MediaPipeline::ArchiveContext.new(config['local']['rar_path'], config['local']['archive_dir'], config['local']['download_dir'])
      transcode_mgr = MediaPipeline::TranscodeManager.new(data_access, context, archive_context, logger:logger)

      queue = data_access.context.sqs_opts[:sqs].queues.named(data_access.context.sqs_opts[:id3_tag_queue_name])
      logger.info(self.class) { MediaPipeline::LogMessage.new('transcode.poll_queue', {queue:queue.url, poll_timeout:options[:poll_timeout]}, 'Starting to poll for messages from SQS').to_s}

      begin
        queue.poll(idle_timeout:options[:poll_timeout], wait_time_seconds:20) do | msg |
          logger.info(self.class) { MediaPipeline::LogMessage.new('transcode.receive_message', {message:msg.body}, 'Received message from SQS queue').to_s}
          payload = JSON.parse(msg.body)
          message = JSON.parse(payload['Message'])
          if message['state'].eql?('COMPLETED')
            transcode_mgr.process_transcoder_output(message['input']['key'],"#{message['outputKeyPrefix']}#{message['outputs'][0]['key']}")
          else
            raise "Unexpected state: #{payload['Message']['state']}"
          end
        end
      rescue => e
        logger.error(self.class) { MediaPipeline::LogMessage.new('transcode.error', {error:e.message}, 'Exception when running process-output command').to_s}
      end
    end

    desc 'analyze', 'This command will scan the directory containing the media files and provide some basic analysis of how much data will be processed'
    option :dir, :required=>true, :banner=>'DIR'
    option :ext, :required=>true, :banner=>'EXT'
    option :output_file, :required=>true, :banner=>'FILE'
    option :egress_data_transfer, :required=>true, :banner=>'BANDWIDTH (mbit/s)'
    long_desc <<-LONGDESC

      The purpose of this command is to compute some data that can be used to estimate the amount of time it will take to copy the media files to S3.  This command will output
      a comma delimited file with the following columns:

      local_dir
      # files
      size (bytes)
      transfer_time (mins)
    LONGDESC
    def analyze
      analysis = {}
      files = Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}")
      files.each do | file |
        key = File.dirname(file)
        if not analysis.key?(key)
          analysis[key] = {}
          analysis[key]['num_files'] = 0
          analysis[key]['size'] = 0
          analysis[key]['transfer_time'] = 0
        end
        analysis[key]['num_files'] = analysis[key]['num_files'] + 1
        analysis[key]['size'] = analysis[key]['size'] + File.size(file)
        analysis[key]['transfer_time'] = (analysis[key]['size']/((options[:egress_data_transfer]/8) * 1024))/60
      end
      begin
        File.open(options[:output_file], 'w') do | file |
          analysis.keys.each do | key |
            file.write([key, analysis[key]['num_files'],analysis[key]['size'], analysis[key]['transfer_time']].join(','))
            file.write('\n')
          end
        end
      ensure
        file.close unless not file
      end
    end

    private

    def init_config(config_file, pipeline_name)
      config = MediaPipeline::ConfigFile.new(config_file, pipeline_name).config
      if config.nil?
        puts "No configuration found for pipeline #{pipeline_name}"
        exit 1
      end
      config
    end

    def init_data_access(config)
      data_access =  MediaPipeline::DataAccess.new(
          MediaPipeline::DataAccessContext.new
          .configure_s3(AWS::S3.new(region:config['aws']['region']),
                        config['s3']['bucket'],
                        :archive_prefix => config['s3']['archive_prefix'],
                        :cover_art_prefix => config['s3']['cover_art_prefix'],
                        :transcode_input_prefix => config['s3']['transcode_input_prefix'],
                        :transcode_output_prefix => config['s3']['transcode_output_prefix'])
          .configure_ddb(AWS::DynamoDB.new(region:config['aws']['region']),
                         config['db']['file_table'],
                         config['db']['archive_table'],
                         AWS::DynamoDB::Client.new(api_version:'2012-08-10', region:config['aws']['region']))
          .configure_sqs(AWS::SQS.new(region:config['aws']['region']),
                         config['sqs']['transcode_queue'],
                         config['sqs']['id3tag_queue'],
                         config['sqs']['cloudplayer_upload_queue']))
      data_access
    end

    def init_archive_context(config)
      archive_context = MediaPipeline::ArchiveContext.new(config['local']['rar_path'], config['local']['archive_dir'], config['local']['download_dir'])
      archive_context
    end

  end
end
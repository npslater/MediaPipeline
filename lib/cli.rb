require 'thor'
require 'aws-sdk'

module MediaPipeline
  class CLI < Thor
    class_option :config, :required=>false, :banner=>'CONFIG FILE', :desc=>'The path to the config file', :default=>'~/.mediapipeline/config'
    class_option :config_key, :required=>false, :banner=>'CONFIG KEY', :desc=>'The configuration key to use when running (e.g. development, test, production', :default=>'production'
    class_option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    class_option :verbose, :required=>false, :type=>:boolean, :desc=>'Verbose logging'

    desc 'process_files', 'Processes the files in the given directory'
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

    option :dir, :required=>true, :banner=>'DIR', :desc=>'The directory to index'
    option :ext, :required=>true, :banner=>'EXT', :desc=>'The extension of files to index'
    def process_files
      config = MediaPipeline::ConfigFile.new(options[:config], options[:config_key]).config
      data_access =  MediaPipeline::DAL::AWS::DataAccess.new(
          MediaPipeline::DAL::AWS::DataAccessContext.new
                                    .configure_s3(AWS::S3.new(region:config['aws']['region']),
                                                  config['s3']['bucket'],
                                                  :archive_prefix => config['s3']['archive_prefix'],
                                                  :cover_art_prefix => config['s3']['cover_art_prefix'],
                                                  :transcode_input_prefix => config['s3']['transcode_input_prefix'],
                                                  :transcode_output_prefix => config['s3']['transcode_output_prefix'])
                                    .configure_ddb(AWS::DynamoDB.new(region:config['aws']['region']),
                                                   config['db']['file_table'],
                                                   config['db']['archive_table'])
                                    .configure_sqs(AWS::SQS.new(region:config['aws']['region']),
                                                   :transcode_queue_name => config['sqs']['transcode_queue'],
                                                   :id3_tag_queue_name =>config['sqs']['id3tag_queue'],
                                                   :cloudplayer_upload_queue_name =>config['sqs']['cloudplayer_upload_queue']))

      logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(options[:log])
      logger.level = options[:verbose].nil? ? Logger::INFO : Logger::DEBUG

      concurrency_mgr = MediaPipeline::ConcurrencyManager.new(config['s3']['concurrent_connections'].to_i)
      concurrency_mgr.logger = logger
      data_access.concurrency_manager = concurrency_mgr

      processor = MediaPipeline::FileProcessor.new(config,
                                                   data_access,
                                                   MediaPipeline::DirectoryFilter.new(options[:dir], options[:ext]),
                                                   logger)
      processor.process_files
    end

    desc 'create', 'Create a media pipeline'
    option :name, :required=>true, :banner=>'NAME', :desc=>'The pipeline name'
    option :template, :required=>true, :banner=>'CFN_TEMPLATE', :desc=>'The path or URL to the CFN template'
    long_desc <<-LONGDESC
      Creates all the AWS resources required for the media pipeline.  Most resources are created using CloudFormation.

      The ElasticTranscoder pipeline is created using SDK calls.
    LONGDESC
    def create
      config = MediaPipeline::ConfigFile.new(options[:config], options[:config_key]).config
      builder = MediaPipeline::PipelineBuilder.new(MediaPipeline::PipelineContext.new(options[:name],
                                                                                      options[:template],
                                                                                      AWS::CloudFormation.new(region:config['aws']['region']),
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
                                                                                      }
                                                   ))
      builder.create
    end
  end
end
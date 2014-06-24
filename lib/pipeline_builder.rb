require 'aws-sdk'

module MediaPipeline
  class PipelineBuilder
    attr_reader :options, :config

    def initialize(options)
      @options = options
      @config = ConfigFile.new(@options[:config]).config
    end

    def name
      @options[:name]
    end

    def create
      cfn = AWS::CloudFormation.new(region:@config['aws']['region'])
      cfn.stacks.create(@options[:name],
                        File.read(@options[:template]),
                        :parameters => {
                            'S3BucketName' => @config['s3']['bucket'],
                            'S3ArchivePrefix' => @config['s3']['archive_prefix'],
                            'S3InputPrefix' => @config['s3']['transcode_input_prefix'],
                            'S3OutputPrefix' => @config['s3']['transcode_output_prefix'],
                            'S3CoverArtPrefix' => @config['s3']['cover_art_prefix'],
                            'DDBFileTable' => @config['db']['file_table'],
                            'DDBArchiveTable' => @config['db']['archive_table'],
                            'TranscodeQueueName' => @config['sqs']['transcode_queue'],
                            'ID3TagQueueName' => @config['sqs']['id3tag_queue'],
                            'CloudPlayerUploadQueueName' => @config['sqs']['cloudplayer_upload_queue']
                        })
    end
  end
end
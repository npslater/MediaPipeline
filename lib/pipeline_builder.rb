require 'aws-sdk'

module MediaPipeline
  class PipelineBuilder
    attr_reader :config, :context

    def initialize(config, pipeline_context)
      @config = config
      @context = pipeline_context
    end

    def create
      @context.cfn.stacks.create(@context.name,
                                 @context.templateUrl? ? @context.template : File.read(@context.template),
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
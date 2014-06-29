require 'spec_helper'

describe MediaPipeline::PipelineBuilder do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', ENV['ENVIRONMENT']).config }
  let!(:cfn) { AWS::CloudFormation.new(region:config['aws']['region'])}
  let!(:transcoder) { AWS::ElasticTranscoder.new(region:config['aws']['region'])}
  let!(:stack_prefix) { 'MediaPipelineRSpec'}

  before(:all) do
    ENV['ENVIRONMENT'] = 'test'
    cleanup_stacks('RSpecPipeline')
  end

  it 'should create the pipeline' do
    builder = MediaPipeline::PipelineBuilder.new(MediaPipeline::PipelineContext.new("#{stack_prefix}#{SecureRandom.uuid}", './cfn/aws.json', cfn, transcoder, {
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
    }))
    stack = builder.create
    stack.outputs.each do | output |
      puts "output: #{output.value}"
    end
    expect(stack.status).to be == 'CREATE_COMPLETE'
  end
end
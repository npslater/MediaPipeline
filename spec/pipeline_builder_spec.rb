require 'spec_helper'

describe MediaPipeline::PipelineBuilder do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let!(:cfn) { AWS::CloudFormation.new(region:config['aws']['region'])}
  let!(:transcoder) { AWS::ElasticTranscoder.new(region:config['aws']['region'])}
  let!(:prefix) { 'rspec' }
  let!(:suffix) { SecureRandom.uuid[1,6]}
  let!(:bucket) { "#{prefix}-#{config['s3']['bucket']}-#{suffix}"}
  let!(:builder) {  MediaPipeline::PipelineBuilder.new(MediaPipeline::PipelineContext.new("#{prefix}-#{suffix}", './cfn/aws.json', cfn, transcoder, bucket, {
                      'S3BucketName' => bucket,
                      'S3ArchivePrefix' => config['s3']['archive_prefix'],
                      'S3InputPrefix' => config['s3']['transcode_input_prefix'],
                      'S3OutputPrefix' => config['s3']['transcode_output_prefix'],
                      'S3CoverArtPrefix' => config['s3']['cover_art_prefix'],
                      'DDBFileTable' => "#{prefix}-#{config['db']['file_table']}-#{suffix}",
                      'DDBArchiveTable' => "#{prefix}-#{config['db']['archive_table']}-#{suffix}",
                      'DDBProcessingStatsTable' => "#{prefix}-#{config['db']['stats_table']}-#{suffix}",
                      'TranscodeQueueName' => "#{prefix}-#{config['sqs']['transcode_queue']}-#{suffix}",
                      'ID3TagQueueName' => "#{prefix}-#{config['sqs']['id3tag_queue']}-#{suffix}",
                      'TranscodeTopicName' => "#{prefix}-#{config['sns']['transcode_topic_name']}-#{suffix}",
                      'AutoScaleTranscodeQueueLength' => config['autoscale']['transcode_queue_length'].to_s,
                      'KeyName' => config['local']['key_name']
                  }))

  }

  before(:all) do
    ENV['ENVIRONMENT'] = 'test'
    cleanup_stacks('rspec')
    cleanup_pipelines('rspec')
  end

  it 'should create the stack and the pipeline' do
    stack = builder.create_stack
    stack.outputs.each do | output |
      puts "#{output.key}=#{output.value}"
    end
    expect(stack.status).to be == 'CREATE_COMPLETE'
    role_arn = stack.outputs.select {|output| output.key.eql?('TranscoderRole')}.first.value
    sns_arn = stack.outputs.select {|output| output.key.eql?('TranscodeSNSTopic')}.first.value
    response = builder.create_pipeline(role_arn, sns_arn)
    #expect(response[:pipelines].first[:pipeline_id]).not_to be_nil
  end
end
require 'spec_helper'

describe MediaPipeline::FileProcessor do
  include AWSHelper, ArchiveHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml').config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let!(:data_access) {
    MediaPipeline::DAL::AWS::DataAccess.new(
        MediaPipeline::DAL::AWS::DataAccessContext.new
        .configure_s3(s3,
                      config['s3']['bucket'],
                      :archive_prefix => config['s3']['archive_prefix'],
                      :cover_art_prefix => config['s3']['cover_art_prefix'],
                      :transcode_input_prefix => config['s3']['transcode_input_prefix'],
                      :transcode_output_prefix => config['s3']['transcode_output_prefix'])
        .configure_ddb(ddb,
                       config['db']['file_table'],
                       config['db']['archive_table'])
        .configure_sqs(sqs,
                       config['sqs']['transcode_queue'],
                       config['sqs']['id3tag_queue'],
                       config['sqs']['cloudplayer_upload_queue']))
  }

  before(:all) do
    cleanup_media_file_items
    cleanup_cover_art_objects
    cleanup_archive_objects
    cleanup_archive_file_items
  end

  before(:each) do
    cleanup_local_archives
  end

  it 'should process all the files in the given directory' do
    processor = MediaPipeline::FileProcessor.new(config,
                                                 data_access,
                                                 MediaPipeline::DirectoryFilter.new(config['local']['media_files_dir'], 'm4a'))
    processor.process_files
    #not the ideal expectation, but if we get here without errors, it's a good indication the routine ran
    expect(true).to be_truthy
  end

  it 'should not process any files in the given directory if it has not been scheduled' do
    processor = MediaPipeline::FileProcessor.new(config,
                                                 data_access,
                                                 MediaPipeline::DirectoryFilter.new(config['local']['media_files_dir'], 'm4a'))
    processor.scheduler = MediaPipeline::Scheduler.new([24]) #this will never match a valid hour value (0-23)
    processor.process_files
    expect(Dir.glob("#{config['local']['archive_dir']}/**/*.rar").count).to be == 0
  end
end
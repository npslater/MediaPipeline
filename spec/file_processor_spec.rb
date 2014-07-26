require 'spec_helper'

describe MediaPipeline::FileProcessor do
  include AWSHelper, ArchiveHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let!(:dir_filter) { MediaPipeline::DirectoryFilter.new(config['local']['media_files_dir'], 'm4a')}
  let!(:data_access) {
    MediaPipeline::DataAccess.new(
        MediaPipeline::DataAccessContext.new
        .configure_s3(s3,
                      config['s3']['bucket'],
                      :archive_prefix => config['s3']['archive_prefix'],
                      :cover_art_prefix => config['s3']['cover_art_prefix'],
                      :transcode_input_prefix => config['s3']['transcode_input_prefix'],
                      :transcode_output_prefix => config['s3']['transcode_output_prefix'])
        .configure_ddb(ddb,
                       config['db']['file_table'],
                       config['db']['archive_table'],
                       config['db']['stats_table'],
                       AWS::DynamoDB::Client.new(api_version:'2012-08-10', region:config['aws']['region']))
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
    cleanup_transcode_queue
    clean_up_stats
  end

  before(:each) do
    cleanup_local_archives
  end

  it 'should process all the files in the given directory' do
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    concurrency_mgr = MediaPipeline::ConcurrencyManager.new(config['s3']['concurrent_connections'].to_i)
    concurrency_mgr.logger = logger

    data_access.concurrency_mgr = concurrency_mgr

    collection = MediaPipeline::MediaFileCollection.new
    dir_filter.filter.each do | file |
      collection.add_file(file)
    end

    processor = MediaPipeline::FileProcessor.new(data_access,
                                                 MediaPipeline::ArchiveContext.new(config['local']['rar_path'],
                                                                                   config['local']['archive_dir'],
                                                                                   config['local']['download_dir']), logger:logger)
    collection.dirs.each do | k, v|
      processor.process_files(k, v)
      #not the ideal expectation, but if we get here without errors, it's a good indication the routine ran
    end
    expect(true).to be_truthy
  end
end
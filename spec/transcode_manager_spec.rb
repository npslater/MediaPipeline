require 'spec_helper'

describe MediaPipeline::TranscodeManager do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml').config }
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }
  let!(:archive_key) { File.dirname(file) }
  let!(:data_access) {
    MediaPipeline::DAL::AWS::DataAccess.new(
        MediaPipeline::DAL::AWS::DataAccessContext.new
        .configure_s3(:s3 => s3,
                      :bucket_name => config['s3']['bucket'],
                      :archive_prefix => config['s3']['archive_prefix'],
                      :cover_art_prefix => config['s3']['cover_art_prefix'])
        .configure_ddb(:ddb => ddb,
                       :file_table_name => config['db']['file_table'],
                       :archive_table_name => config['db']['archive_table'])
        .configure_sqs(:sqs => sqs,
                       :transcode_queue_name => config['sqs']['transcode_queue'],
                       :id3_tag_queue_name =>config['sqs']['id3tag_queue'],
                       :cloudplayer_upload_queue_name =>config['sqs']['cloudplayer_upload_queue']))
  }

  it 'should return an instance of TranscodeManager' do
    transcode_mgr = MediaPipeline::TranscodeManager.new({:verbose=>true, :config=>'./conf/config.yml'})
    expect(transcode_mgr).to be_an_instance_of(MediaPipeline::TranscodeManager)
  end

  def write_and_save_archive(archive_key)
    extract_path = "#{File.basename(File.dirname(file))}/#{File.basename(file)}"
    archive = MediaPipeline::RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)

    parts = archive.archive
    keys = data_access.write_archive(parts)
    data_access.save_archive(archive_key, keys)
  end

  it 'should prepare the input files to the transcoding pipeline job' do
    write_and_save_archive(archive_key)

  end

end
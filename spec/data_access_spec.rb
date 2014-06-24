require 'spec_helper'

describe MediaPipeline::DAL::AWS::DataAccess do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml').config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }
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

  before(:all) do
    cleanup_media_file_items
    cleanup_cover_art_objects
    cleanup_archive_objects
    cleanup_local_archives
    cleanup_archive_file_items
    cleanup_transcode_queue
  end

  it 'should return an instance of DataAccess' do
    data_access = MediaPipeline::DAL::AWS::DataAccess.new(MediaPipeline::DAL::AWS::DataAccessContext.new)
    expect(data_access).to be_an_instance_of(MediaPipeline::DAL::AWS::DataAccess)
  end

  it 'should return a hashtable of s3 options' do
    data_access = MediaPipeline::DAL::AWS::DataAccess.new(MediaPipeline::DAL::AWS::DataAccessContext.new)
    expect(data_access.context.s3_opts).to be_an_instance_of(Hash)
  end

  it 'should return a hashtable of ddb options' do
    data_access = MediaPipeline::DAL::AWS::DataAccess.new(MediaPipeline::DAL::AWS::DataAccessContext.new)
    expect(data_access.context.ddb_opts).to be_an_instance_of(Hash)
  end

  it 'should save a media file to dynamoDB' do
    media_file = MediaPipeline::MediaFile.new(file)
    data_access.save_media_file(media_file)

    #read the item back out and check the attributes
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = [:local_file_path, :string]
    table.range_key = [:local_dir, :string]
    item = table.items.at(File.absolute_path(file), File.dirname(File.absolute_path(file)))
    expect(item).not_to be_nil
    expect(item.attributes['album']).not_to be_nil
  end

  it 'should fetch the dynamoDB item if there is one' do
    item = data_access.fetch_media_file_item(file)
    expect(item.attributes['local_file_path']).to be_instance_of(String)
  end

  it 'should write the cover art to an S3 bucket' do
    media_file = MediaPipeline::MediaFile.new(file)
    key = data_access.write_cover_art(media_file)
    expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to eql(true)
  end

  it 'should write the archive parts to S3' do
    collection = MediaPipeline::MediaFileCollection.new
    collection.add_file(file)
    collection.dirs.each do | k, v|
      extract_path = "#{File.basename(File.dirname(k))}/#{File.basename(k)}"
      archive = MediaPipeline::RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
      v.each do | media_file |
        archive.add_file(media_file.file)
      end
      parts = archive.archive
      keys = data_access.write_archive(parts)
      keys.each do | key |
        expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to eql(true)
      end
    end
  end

  it 'should save the archive items to dynamoDB' do
    collection = MediaPipeline::MediaFileCollection.new
    collection.add_file(file)
    collection.dirs.each do | k, v|
      extract_path = "#{File.basename(File.dirname(k))}/#{File.basename(k)}"
      archive = MediaPipeline::RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
      v.each do | media_file |
        archive.add_file(media_file.file)
      end
      parts = archive.archive
      keys = data_access.write_archive(parts)
      data_access.save_archive(k, keys)
    end
    table = ddb.tables[config['db']['archive_table']]
    table.hash_key = :local_dir, :string
    expect(table.items.count).to be > 0
  end

  it 'should queue up a transcode task' do
    parent_dir = File.dirname(file)
    data_access.queue_transcode_task(parent_dir)

    queue = sqs.queues.named(config['sqs']['transcode_queue'])
    queue.poll(:initial_timeout=>2, :idle_timeout=>2) { |msg| expect(msg.body.include?(parent_dir)).to be_truthy }

  end

  it 'should fetch the archive item from dynamoDB' do
    write_and_save_archive(file, config, data_access)
    item = data_access.fetch_archive_item(File.dirname(file))
    expect(item.attributes.count).to be > 0
  end
end
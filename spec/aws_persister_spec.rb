require 'spec_helper'

describe AWSPersister do
  include AWSHelper

  let!(:config) { ConfigFile.new('./conf/config.yml').config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let!(:persister) {
      persister = AWSPersister.new(
      :ddb => ddb,
      :s3 => s3,
      :sqs => sqs,
      :file_table_name => config['db']['file_table'],
      :archive_table_name => config['db']['archive_table'],
      :bucket_name => config['s3']['bucket'],
      :archive_prefix => config['s3']['archive_prefix'],
      :cover_art_prefix => config['s3']['cover_art_prefix'])
  }

  before(:all) do
    cleanup_media_file_items
    cleanup_cover_art_objects
    cleanup_archive_objects
    cleanup_local_archives
    cleanup_archive_file_items
  end

  it 'should return an ArgumentError if there are missing options' do
    begin
      persister = AWSPersister.new
    rescue ArgumentError => e
      expect(e).to be_instance_of(ArgumentError)
    end
  end

  it 'should return an instance of AWSPersister if all the options are set during construction' do
    begin
      persister = AWSPersister.new(
          :ddb => 'dynamoclient',
          :s3 => 's3client',
          :sqs => 'sqs',
          :file_table_name => 'table',
          :archive_table_name => config['db']['archive_table'],
          :bucket_name => 'bucket',
          :archive_prefix => 'prefix',
          :cover_art_prefix => 'prefix')
    rescue ArgumentError => e
      expect(false).to be_truthy
    end
  end

  it 'should save a media file to dynamoDB' do
    file = Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").first
    media_file = MediaFile.new(file)
    persister.save_media_file(media_file)

    #read the item back out and check the attributes
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = [:local_file_path, :string]
    table.range_key = [:local_dir, :string]
    item = table.items.at(File.absolute_path(file), File.dirname(File.absolute_path(file)))
    expect(item).not_to be_nil
    expect(item.attributes['album']).not_to be_nil
  end

  it 'should fetch the dynamoDB item if there is one' do
    file = Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").first
    item = persister.fetch_media_file_item(file)
    expect(item.attributes['local_file_path']).to be_instance_of(String)
  end

  it 'should write the cover art to an S3 bucket' do
    file = Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").first
    media_file = MediaFile.new(file)
    key = persister.write_cover_art(media_file)
    expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to eql(true)
  end

  it 'should write the archive parts to S3' do
    collection = MediaFileCollection.new
    collection.add_file(Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").first)
    collection.dirs.each do | k, v|
      extract_path = "#{File.basename(File.dirname(k))}/#{File.basename(k)}"
      archive = RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
      v.each do | media_file |
        archive.add_file(media_file.file)
      end
      parts = archive.archive
      keys = persister.write_archive(parts)
      keys.each do | key |
        expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to eql(true)
      end
    end
  end

  it 'should save the archive items to dynamoDB' do
    collection = MediaFileCollection.new
    collection.add_file(Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").first)
    collection.dirs.each do | k, v|
      extract_path = "#{File.basename(File.dirname(k))}/#{File.basename(k)}"
      archive = RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
      v.each do | media_file |
        archive.add_file(media_file.file)
      end
      parts = archive.archive
      keys = persister.write_archive(parts)
      persister.save_archive(k, keys)
    end
    table = ddb.tables[config['db']['archive_table']]
    table.hash_key = :local_dir, :string
    expect(table.items.count).to be > 0
  end
end
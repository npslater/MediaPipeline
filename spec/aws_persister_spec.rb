require 'spec_helper'

describe AWSPersister do

  let!(:config) { YAML.load(File.read('./conf/config.yml'))}
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:persister) {
      persister = AWSPersister.new(
      :ddb => ddb,
      :s3 => s3,
      :table_name => config['db']['file_table'],
      :bucket_name => config['s3']['bucket'],
      :archive_prefix => config['s3']['archive_prefix'],
      :cover_art_prefix => config['s3']['cover_art_prefix'])
  }

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
          :table_name => 'table',
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
    object = persister.write_cover_art(media_file)
    expect(s3.buckets[config['s3']['bucket']].objects[object.key].exists?).to eql(true)
  end
end
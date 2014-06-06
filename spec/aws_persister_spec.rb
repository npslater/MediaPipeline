require 'spec_helper'

describe AWSPersister do

  let!(:config) { YAML.load(File.read('./conf/config.yml'))}
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}

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
    begin
      persister = AWSPersister.new(
          :ddb => ddb,
          :s3 => 's3client',
          :table_name => config['db']['file_table'],
          :bucket_name => 'bucket',
          :archive_prefix => 'prefix',
          :cover_art_prefix => 'prefix')
      persister.save_media_file(media_file)
    rescue ArgumentError => e
      expect(false).to be_truthy
    end
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = [:local_file_path, :string]
    table.range_key = [:local_dir, :string]
    item = table.items.at(File.absolute_path(file), File.dirname(File.absolute_path(file)))
    expect(item).not_to be_nil
    expect(item.attributes['album']).not_to be_nil
  end
end
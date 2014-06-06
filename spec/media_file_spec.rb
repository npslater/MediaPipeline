require_relative 'spec_helper'

describe MediaFile do

  let!(:config) { YAML.load(File.read('./conf/config.yml'))}
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}

  it 'should have a getter for the file property' do
    mf = MediaFile.new('/this/is/the/path')
    expect(mf).not_to be_nil
  end

  it 'should return a hash when tag_data is called' do
    mf = MediaFile.new('./media_files/file1.m4a')
    expect(mf.tag_data).to be_an_instance_of(Hash)
  end

  it 'should persist itself when save is called' do
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = [:local_file_path, :string]
    table.range_key = [:local_dir, :string]
    Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").each do | file |
      mf = MediaFile.new(file)
      mf.save do
        item = table.items.create(
            'local_file_path' =>File.absolute_path(mf.file),
            'local_dir' => File.dirname(File.absolute_path(mf.file)))
        #object =
      end

    end
  end
end
require 'spec_helper'
require 'aws-sdk'
require 'yaml'

describe MediaFile do

  let!(:config) { YAML.load(File.read('./conf/config.yml'))}
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}

  it 'should have a getter for the file property' do
    mf = MediaFile.new('/this/is/the/path')
    expect(mf).not_to be_nil
  end

  it 'should return a hash when tag_data is called' do
    mf = MediaFile.new('./media_files/file1.m4a')
    expect(mf.tag_data).to be_an_instance_of(Hash)
  end

  it 'should persist itself when save is called' do
    puts config['aws']['region']
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = [:LOCAL_FILE_PATH, :string]
    table.range_key = [:LOCAL_DIR, :string]
    puts table.name
    Dir.glob('./media_files/**/*.m4a').each do | file |
      mf = MediaFile.new(file)
      mf.save { table.items.create('LOCAL_FILE_PATH' =>File.absolute_path(file), 'LOCAL_DIR' => File.dirname(File.absolute_path(file)))}
    end
  end
end
require 'spec_helper'

describe MediaFileCollection do

  let!(:config) { ConfigFile.new('./conf/config.yml').config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}

  it 'should return an instance of MediaFileCollection' do
    collection = MediaFileCollection.new
    expect(collection).to be_an_instance_of(MediaFileCollection)
  end

  it 'should return a hash when the dirs property is called' do
    collection = MediaFileCollection.new
    expect(collection.dirs).to be_an_instance_of(Hash)
  end

  it 'should return a collection of files for each directory' do
    collection = MediaFileCollection.new
    Dir.glob("#{config['local']['sample_media_files_dir']}/**/*.m4a").each do | file |
      collection.add_file(file)
    end
    expect(collection.dirs.keys.length).to be > 0
  end
end
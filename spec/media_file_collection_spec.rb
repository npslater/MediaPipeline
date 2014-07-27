require 'spec_helper'

describe MediaPipeline::MediaFileCollection do

  let!(:config) { MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}

  it 'should return an instance of MediaFileCollection' do
    collection = MediaPipeline::MediaFileCollection.new
    expect(collection).to be_an_instance_of(MediaPipeline::MediaFileCollection)
  end

  it 'should return a hash when the dirs property is called' do
    collection = MediaPipeline::MediaFileCollection.new
    expect(collection.dirs).to be_an_instance_of(Hash)
  end

  it 'should return a collection of files for each directory' do
    collection = MediaPipeline::MediaFileCollection.new
    Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").each do | file |
      collection.add_file(file)
    end
    expect(collection.dirs.keys.length).to be > 0
  end
end
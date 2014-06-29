require_relative 'spec_helper'

describe MediaPipeline::MediaFile do

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', ENV['ENVIRONMENT']).config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }

  it 'should have a getter for the file property' do
    mf = MediaPipeline::MediaFile.new('/this/is/the/path')
    expect(mf).not_to be_nil
  end

  it 'should return a hash when tag_data is called' do
    mf = MediaPipeline::MediaFile.new(file)
    expect(mf.tag_data).to be_an_instance_of(Hash)
  end

  it 'should return the binary data when cover_art is called' do
    mf = MediaPipeline::MediaFile.new(file)
    expect(mf.cover_art).to be_an_instance_of(String)
  end
end
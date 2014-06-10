require_relative 'spec_helper'

describe MediaFile do

  let!(:config) { ConfigFile.new('./conf/config.yml').config }
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

  it 'should return the binary data when cover_art is called' do
    mf = MediaFile.new('./media_files/file1.m4a')
    expect(mf.cover_art).to be_an_instance_of(String)
  end
end
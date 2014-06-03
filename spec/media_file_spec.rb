require 'spec_helper'

describe MediaFile do

  it 'should have a getter for the file property' do
    mf = MediaFile.new('/this/is/the/path')
    expect(mf).not_to be_nil
  end

  it 'should do nothing' do

  end

  it 'should return a hash when tag_data is called' do
    mf = MediaFile.new('./media_files/file1.m4a')
    expect(mf.tag_data).to be_an_instance_of(Hash)
  end
end
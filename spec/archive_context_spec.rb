require 'spec_helper'

describe MediaPipeline::ArchiveContext do

  it 'should return the rar path' do
    context = MediaPipeline::ArchiveContext.new('/rar/path', '/archive_dir')
    expect(context.rar_path.eql?('/rar/path')).to be_truthy
  end

  it 'should return the archive_dir' do
    context = MediaPipeline::ArchiveContext.new('/rar/path', '/archive_dir')
    expect(context.archive_dir.eql?('/archive_dir')).to be_truthy
  end

end
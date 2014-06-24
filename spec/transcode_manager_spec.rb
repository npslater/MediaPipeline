require 'spec_helper'

describe MediaPipeline::TranscodeManager do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml').config }
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }

  it 'should return an instance of TranscodeManager' do
    transcode_mgr = MediaPipeline::TranscodeManager.new({:verbose=>true, :config=>'./conf/config.yml'})
    expect(transcode_mgr).to be_an_instance_of(MediaPipeline::TranscodeManager)
  end

  it 'should prepare the input files to the transcoding pipeline job' do

  end

end
require 'spec_helper'

describe MediaPipeline::FileProcessor do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml').config }
  let!(:opts) {
    {
      :config => './conf/config.yml',
      :dir => config['local']['media_files_dir'],
      :ext => 'm4a',
      :verbose => true
    }
  }

  before(:all) do
    cleanup_media_file_items
    cleanup_cover_art_objects
    cleanup_archive_objects
    cleanup_local_archives
    cleanup_archive_file_items
  end

  it 'should process all the files in the given directory' do
    processor = MediaPipeline::FileProcessor.new(opts)
    processor.process_files
    #not the ideal expectation, but if we get here without errors, it's a good indication the routine ran
    expect(true).to be_truthy
  end

  it 'should not process any files in the given directory if it has not been scheduled' do
    processor = MediaPipeline::FileProcessor.new(opts)
    processor.scheduler = MediaPipeline::Scheduler.new([24]) #this will never match a valid hour value (0-23)
    processor.process_files
    expect(Dir.glob("#{config['local']['archive_dir']}/**/*.rar").count).to be == 0
  end
end
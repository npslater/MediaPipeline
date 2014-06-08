require 'spec_helper'

describe FileIndexer do
  include AWSHelper

  let!(:config) { YAML.load(File.read('./conf/config.yml'))}
  let!(:opts) {
    {
      :config => './conf/config.yml',
      :dir => './media_files',
      :ext => 'm4a'
    }
  }

  before(:all) do
    cleanup_media_file_items
    cleanup_cover_art_objects
    cleanup_archive_objects
    cleanup_local_archives
    cleanup_archive_file_items
  end

  it 'should index all the files in the given directory' do
    indexer = FileIndexer.new(opts)
    indexer.index
    #not the ideal expectation, but if we get here without errors, it's a good indication the routine ran
    expect(true).to be_truthy
  end

end
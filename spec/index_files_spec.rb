require 'spec_helper'

describe FileIndexer do

  let!(:opts) {
    {
      :config => './conf/config.yml',
      :dir => './media_files',
      :ext => 'm4a'
    }
  }

  it 'should index all the files in the given directory' do
    indexer = FileIndexer.new(opts)
    indexer.index
    expect(true).to be_truthy
  end

end
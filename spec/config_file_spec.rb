require 'spec_helper'

describe MediaPipeline::ConfigFile do

  it 'should return the development settings' do
    ENV['ENVIRONMENT'] = 'development'
    config = MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config
    expect(config['db']['file_table'].include?('dev')).to be_truthy
  end

  it 'should return the production settings' do
    config = MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config
    expect(config['db']['file_table'].include?('dev')).to be_falsey
  end
end
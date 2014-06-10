require 'spec_helper'

describe ConfigFile do

  it 'should return the development settings' do
    ENV['ENVIRONMENT'] = 'development'
    config = ConfigFile.new('./conf/config.yml').config
    expect(config['db']['file_table'].include?('dev')).to be_truthy
  end

  it 'should return the production settings' do
    ENV['ENVIRONMENT'] = nil #production is the default if not set
    config = ConfigFile.new('./conf/config.yml').config
    expect(config['db']['file_table'].include?('dev')).to be_falsey
  end
end
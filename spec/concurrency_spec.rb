require 'spec_helper'

describe ConcurrencyManager do

  it 'should return an instance of ConcurrencyManager' do
    cm = ConcurrencyManager.new(1)
    expect(cm).to be_an_instance_of(ConcurrencyManager)
  end

  it 'should wait when the maximum number of concurrent operations has been reached' do
    cm = ConcurrencyManager.new(1)
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    cm.logger = logger
    before = Time.new
    cm.run_async { sleep 5 }
    cm.run_async { sleep 5 }
    after = Time.new
    expect(after - before).to be > 0.5
  end
end
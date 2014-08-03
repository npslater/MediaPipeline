require 'spec_helper'

describe MediaPipeline::LogReader do

  let!(:message) { 'I, [2014-08-01T14:10:21.077959 #1013]  INFO -- MediaPipeline::FileProcessor: {"event":"data_access.write_cover_art","data":{"key":"cover_art/e78df78.jpg"},"message":"test"}'}
  let!(:config) { MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let(:kinesis) { AWS::Kinesis.new(region:config['aws']['region'])}

  before(:all) do
    cfg = MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config
    Dir.glob("#{cfg['local']['buffer_dir']}/*.log").each do | log |
      File.delete(log)
    end
  end


  it 'should parse the log data' do
    data = MediaPipeline::LogReader.parse(message)
    expect(data).to be_an_instance_of(Hash)
    expect(data[:date]).to be == '2014-08-01'
    expect(data[:time]).to be == '14:10:21.077959'
    expect(data[:class]).to be == 'MediaPipeline::FileProcessor'
    expect(data[:event]).to be == 'data_access.write_cover_art'
    expect(data[:message]).to be == 'test'
    expect(data[:data]).to be_an_instance_of(Hash)
    expect(data[:data]['key']).to be == 'cover_art/e78df78.jpg'
  end

  it 'should write messages to the stream' do
    reader = MediaPipeline::LogReader.new
    begin
      file = File.open("./spec/#{config['local']['sample_log_file_name']}", 'r')
      reader.process_stream(file, $stderr, kinesis, config['local']['buffer_dir'], config['kinesis']['stream_name'], 'log_reader_spec')
      expect(Dir.glob("#{config['local']['buffer_dir']}/*.log").count).to be == 0
    ensure
      file.close unless file.nil?
    end
  end

  it 'should buffer messages on errors writing to the stream' do
    reader = MediaPipeline::LogReader.new
    begin
      file = File.open("./spec/#{config['local']['sample_log_file_name']}", 'r')
      reader.process_stream(file, $stderr, kinesis, config['local']['buffer_dir'], 'fake_stream_name', 'log_reader_spec')
      expect(File.size(Dir.glob("#{config['local']['buffer_dir']}/*.log").first)).to be > 0
    ensure
      file.close unless file.nil?
    end
  end

  it 'should process the buffered messages' do
    reader = MediaPipeline::LogReader.new

    #put some messages in the local buffer
    i = 0
    until i >= 2
      begin
        file = File.open("./spec/#{config['local']['sample_log_file_name']}", 'r')
        reader.process_stream(file, $stderr, kinesis, config['local']['buffer_dir'], 'fake_stream_name', 'log_reader_spec')
        i+=1
      ensure
        file.close unless file.nil?
      end
    end
    begin
      file = File.open("./spec/#{config['local']['sample_log_file_name']}", 'r')
      reader.process_buffered_messages($stderr, kinesis, config['local']['buffer_dir'], config['kinesis']['stream_name'], 'log_reader_spec')
      expect(Dir.glob("#{config['local']['buffer_dir']}/*.log").count).to be == 0
    ensure
      file.close unless file.nil?
    end
  end

  it 'should print the records from the stream' do
    reader = MediaPipeline::LogReader.new
    reader.print_stream(kinesis, config['kinesis']['stream_name'], 'shardId-000000000000', 120)
  end
end
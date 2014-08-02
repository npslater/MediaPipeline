require 'spec_helper'

describe MediaPipeline::LogReader do

  let!(:message) { 'I, [2014-08-01T14:10:21.077959 #1013]  INFO -- MediaPipeline::FileProcessor: {"event":"data_access.write_cover_art","data":{"key":"cover_art/e78df78.jpg"},"message":"test"}'}
  let!(:config) { MediaPipeline::ConfigFile.new('./spec/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }


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

  it 'should parse out the date and time' do
    info = MediaPipeline::LogReader.parse_date_time(message)
    expect(info[:date]).to be == '2014-08-01'
    expect(info[:time]).to be == '14:10:21.077959'
  end

  it 'should parse out the class' do
    class_name = MediaPipeline::LogReader.parse_class(message)
    expect(class_name).to be == 'MediaPipeline::FileProcessor'
  end

  it 'should parse out the data' do
    data = MediaPipeline::LogReader.parse_data(message)
    puts data
  end

  it 'should parse the log message and return a JSON string' do
    json = MediaPipeline::LogReader.convert_to_json(message)
    expect(json).to be_an_instance_of(String)
  end

  it 'should write a message to the kinesis stream' do
    kinesis = AWS::Kinesis.new(region:config['aws']['region'])
    for i in 0..100
      result = kinesis.client.put_record(stream_name:config['kinesis']['stream_name'],
                         data:JSON.generate(MediaPipeline::LogReader.parse(message)),
                         partition_key: PIPELINES[ENV['ENVIRONMENT']],
                         sequence_number_for_ordering:i.to_s)
      expect(result[:shard_id]).not_to be_nil
      expect(result[:sequence_number]).not_to be_nil
    end
  end

end
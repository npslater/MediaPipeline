require 'json'
require 'thor'
require 'aws-sdk'

module MediaPipeline
  class LogReaderCLI < Thor
    desc 'stream', 'Write the log messages to a kinesis stream'
    option :region, :required=>true
    option :stream_name, :required=>true
    option :command_name, :required=>true
    option :buffer_dir, :required=>true
    long_desc <<-LONGDESC
      Parses the log message, converts it to JSON and puts it onto the kinesis stream given by the stream-name arg.
    LONGDESC
    def stream
      kinesis = AWS::Kinesis.new(region:options[:region])
      reader = MediaPipeline::LogReader.new
      reader.process_stream($stdin, $stderr, kinesis, options[:buffer_dir], options[:stream_name], options[:command_name])
      reader.process_buffered_messages($stderr, kinesis, options[:buffer_dir], options[:stream_name], options[:command_name])
    end
  end
end
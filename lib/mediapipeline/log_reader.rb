require 'json'
require 'thor'
require 'aws-sdk'

module MediaPipeline
  class LogReader < Thor

    desc 'stream', 'Write the log messages to a kinesis stream'
    option :region, :required=>true
    option :stream_name, :required=>true
    option :pipeline_name, :required=>true
    long_desc <<-LONGDESC
      Parses the log message, converts it to JSON and puts it onto the kinesis stream given by the stream-name arg.
    LONGDESC
    def stream
      kinesis = AWS::Kinesis.new(region:options[:region])
      while line = $stdin.gets
        kinesis.client.put_record(stream_name: options[:stream_name],
                                  data:JSON.generate(LogReader.parse(line)),
                                  partition_key: options[:pipeline_name])
      end
    end

    def LogReader.parse(message)
      md = /I,\s+\[(\S+)T(\S+).*\].*--\s+(\w+::\w+):\s+(.*)/.match(message)
      payload = JSON.parse(md[4])
      info = {
          date:md[1],
          time:md[2],
          class:md[3],
          event:payload['event'],
          message:payload['message'],
          data:payload['data']
      }
      info
    end
  end
end
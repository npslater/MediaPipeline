require 'json'
require 'aws-sdk'

module MediaPipeline
  class LogReader

    def process_stream(stdin, stderr, kinesis, buffer_dir, stream_name, command_name)
      log_file = log_file_name(buffer_dir, command_name)
      File.open(log_file, 'w') do | file |
      current_sequence = '0'
        while line = stdin.gets
          begin
            line.chomp
            data = JSON.generate(LogReader.parse(line))
            result = kinesis.client.put_record(stream_name: stream_name, data:data, partition_key:command_name, sequence_number_for_ordering:current_sequence)
            current_sequence = result[:sequence_number] unless result.nil?
          rescue => e
            stderr.puts("Error writing to stream: #{e.message}")
            file.write(line)
          end
        end
      end
      if File.size(log_file) == 0
        File.delete(log_file)
      end
    end

    def process_buffered_messages(stderr, kinesis, buffer_dir, stream_name, command_name)
      logs = Dir.glob("#{buffer_dir}/*.log")
      logs.each do | log |
        unprocessed = []
        File.open(log, 'r') do | file |
          current_sequence = '0'
          while line = file.gets
            begin
              line.chomp
              data = JSON.generate(LogReader.parse(line))
              result = kinesis.client.put_record(stream_name: stream_name, data:data, partition_key:command_name, sequence_number_for_ordering:current_sequence)
              current_sequence = result[:sequence_number] unless result.nil?
            rescue => e
              stderr.puts("Error writing buffered messages to stream: #{e.message}")
              unprocessed.push line
            end
          end
        end
        File.delete(log)
        if unprocessed.count > 0
          File.open(log_file_name(buffer_dir, command_name), 'w') do | file |
            unprocessed.each do | line |
              file.write(line)
            end
          end
        end
      end
    end

    def print_stream(kinesis, stream_name, shard_id, duration)
      iterator = kinesis.client.get_shard_iterator(stream_name:stream_name, shard_id:shard_id, shard_iterator_type:'LATEST')
      iterator_id = iterator[:shard_iterator]
      total_time = 0
      while total_time < duration
        result = kinesis.client.get_records(shard_iterator:iterator_id, limit:1000)
        result[:records].each do | record |
          puts "#{record}\n"
        end
        iterator_id = result[:next_shard_iterator]
        sleep 1
        total_time +=1
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

    private
    def log_file_name(buffer_dir, command_name)
      File.join(buffer_dir, "#{SecureRandom.uuid[0..6]}_#{command_name}_stream.log")
    end
  end
end
require 'thor'

module MediaPipeline
  class Analyze < Thor

    PERCENTILES = [0.99, 0.95, 0.90, 0.85, 0.80, 0.75]

    desc 'storage', 'Estimate the amount of storage that will be required to process all the media files in a given directory'
    option :dir, :required=>true
    option :input_file_ext, :required=>true
    option :delimiter, :required=>false, :default=>','
    def storage
      analysis = {
          sizes:[],
          count:0,
          dirs:{}
      }
      files = Dir.glob("#{options[:dir]}/**/*.#{options[:input_file_ext]}")
      files.each do | file |
        analysis[:dirs][File.dirname(file)] = {
            sizes:[],
            count:0
        } unless analysis[:dirs][File.dirname(file)]
        analysis[:dirs][File.dirname(file)][:sizes].push(File.size(file))
        analysis[:dirs][File.dirname(file)][:count] = analysis[:dirs][File.dirname(file)][:count] + 1
        analysis[:sizes].push(File.size(file))
        analysis[:count] = analysis[:count] + 1
      end
      total_size = analysis[:sizes].inject(0) { |total,size| total + size}
      average = average(analysis[:sizes])
      median = median(analysis[:sizes])

      puts "total files: #{analysis[:count]}\n"
      puts "statistic#{options[:delimiter]}size(bytes)#{options[:delimiter]}size(mb)\n"

      print_sizes('total size', total_size, options[:delimiter])
      print_sizes('average size', average, options[:delimiter])
      print_sizes('median size', median, options[:delimiter])

      PERCENTILES.each do | percentile |
        p = percentile(analysis[:sizes], percentile)
        print_sizes("#{percentile} pct", p, options[:delimiter])
      end


      dir_sizes = []
      analysis[:dirs].keys.each do | dir |
        dir_sizes.push(analysis[:dirs][dir][:sizes].inject(0){|total,size| total + size})
      end
      total_size = dir_sizes.inject(0){|total,size| total+size}
      average = average(dir_sizes)
      median = median(dir_sizes)

      puts "\n\n"
      puts "total dirs: #{analysis[:dirs].keys.count}"
      puts "statistic#{options[:delimiter]}size(bytes)#{options[:delimiter]}size(mb)\n"
      print_sizes('total size', total_size, options[:delimiter])
      print_sizes('average size', average, options[:delimiter])
      print_sizes('median size', median, options[:delimiter])

      PERCENTILES.each do | percentile |
        p = percentile(dir_sizes, percentile)
        print_sizes("#{percentile} pct", p, options[:delimiter])
      end

    end

    desc 'database', 'Estimate the amount of each item in the database.  This can be used to determine the minimum number of read/write IOPS'
    option :dir, :required=>true
    option :input_file_ext, :required=>true
    option :delimiter, :required=>false, :default=>','
    def database
      analysis = {
          hash_key_len:[],
          range_key_len:[],
          attribute_len:[],
          audio_len:[]
      }
      collection = MediaPipeline::MediaFileCollection.new
      files = Dir.glob("#{options[:dir]}/**/*.#{options[:input_file_ext]}")
      files.each do | file |
        collection.add_file(file)
      end
      collection.dirs.each do | k,v |
        analysis[:range_key_len].push(k.length)
        v.each do | media_file |
          analysis[:hash_key_len].push(media_file.file.length)
          tag_length = 0
          media_file.tag_data(false).keys.each do | tag |
            tag_length = tag_length + media_file.tag_data[tag].to_s.length
          end
          analysis[:attribute_len].push(tag_length)
          if not media_file.tag_data(false)[:length].eql?(nil)
            analysis[:audio_len].push(media_file.tag_data(false)[:length])
          else
            analysis[:audio_len].push(0)
          end
        end
      end
      puts "total items: #{analysis[:hash_key_len].count}"
      puts "total audio length: #{analysis[:audio_len].inject(0) {|total, len| total+len}}"
      puts "statistic#{options[:delimiter]}length(chars)\n"
      puts "avg hash key len#{options[:delimiter]}#{average(analysis[:hash_key_len])}\n"
      puts "avg range key len#{options[:delimiter]}#{average(analysis[:range_key_len])}\n"
      puts "avg attributes len#{options[:delimiter]}#{average(analysis[:attribute_len])}\n"
      puts "avg audio len#{options[:delimiter]}#{average(analysis[:audio_len])}\n"
      puts "med hash key len#{options[:delimiter]}#{median(analysis[:hash_key_len])}\n"
      puts "med range key len#{options[:delimiter]}#{median(analysis[:range_key_len])}\n"
      puts "med attributes len#{options[:delimiter]}#{median(analysis[:attribute_len])}\n"
      puts "med audio len#{options[:delimiter]}#{median(analysis[:audio_len])}\n"

      analysis.keys.each do | key |
        PERCENTILES.each do | percentile |
          puts "#{percentile} pct #{key}#{options[:delimiter]}#{(percentile(analysis[key], percentile)).round(2)}\n"
        end
      end

    end

    private
    def print_sizes(name, size, delimiter)
      puts "#{name}#{delimiter}#{size}#{delimiter}#{(size/(1024*1024)).round(2)}\n"
    end

    def percentile(values, percentile)
      values_sorted = values.sort
      k = (percentile*(values_sorted.length-1)+1).floor - 1
      f = (percentile*(values_sorted.length-1)+1).modulo(1)

      return values_sorted[k] + (f * (values_sorted[k+1] - values_sorted[k]))
    end

    def average(values)
      total = values.inject(0) {|total,size| total+size}
      total/values.count
    end

    def median(array)
      sorted = array.sort
      len = sorted.length
      return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
    end
  end
end
require 'optparse'
require 'aws-sdk'
require 'Taglib'
require 'yaml'
require_relative '../lib/media_file'
require_relative '../lib/aws_persister'
require_relative '../lib/media_file_collection'

class FileIndexer

  attr_reader :options, :config

  def initialize(options)
    @options = options
    @config = YAML.load(File.read(@options[:config]))
  end

  def FileIndexer.parse(args)

    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: index_files.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"
      opts.on('-c', '--config CONFIG', 'The path to the config file') do | config |
        options[:config] = config
      end
      opts.on('-d', '--dir DIR',
              'The directory to index') do | dir |
        options[:dir] = dir
      end

      opts.on('-e', '--ext EXTENSION', 'The extension of files to index') do | ext |
        options[:ext] = ext
      end
    end
    parser.parse!(args)
    mandatory = [:dir, :ext, :config]
    missing = mandatory.select{|param| options[param].nil?}
    if not missing.empty?
      puts "Missing options: #{missing.join(', ')}"
      raise ArgumentError, opts.to_s
    end
    options
  end

  def index
    collection = MediaFileCollection.new
    persister = AWSPersister.new(
        :ddb => AWS::DynamoDB.new(region:@config['aws']['region']),
        :s3 => AWS::S3.new(region:@config['aws']['region']),
        :table_name => @config['db']['file_table'],
        :bucket_name => @config['s3']['bucket'],
        :archive_prefix => @config['s3']['archive_prefix'],
        :cover_art_prefix => @config['s3']['cover_art_prefix'])

    Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}").each do | file |
      collection.add_file(file)
    end
    collection.dirs.each do | k,v |
      v.each do | media_file |
        print "Processing file: #{media_file.file}..."
        media_file.save do
          persister.save_media_file(media_file)
          print 'saved...'
        end

        media_file.write_cover_art do
          persister.write_cover_art(media_file)
          print 'wrote cover art...file processing complete'
          puts
        end
      end
    end
  end
end

if __FILE__ == $0
  begin
    indexer = FileIndexer.new(FileIndexer.parse(ARGV))
    indexer.index
  rescue ArgumentError => e
    puts e.message
    exit
  end
end



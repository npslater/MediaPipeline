require 'optparse'
require 'aws-sdk'
require 'Taglib'
require 'yaml'
require 'logger'
require_relative '../lib/media_file'
require_relative '../lib/aws_persister'
require_relative '../lib/media_file_collection'
require_relative '../lib/rar_archive'

class FileIndexer

  attr_reader :options, :config

  def initialize(options)
    @options = options
    @config = YAML.load(File.read(@options[:config]))
    @logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(@options[:log])
    @logger.level = @options[:verbose] ? Logger::DEBUG : Logger::INFO
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

      opts.on('-l', '--log LOGFILE',
              'The path to the log file (optional).  If not given, STDOUT will be used') do | log |
        options[:log] = log
      end

      opts.on('-v', '--verbose', 'Verbose logging') do | v |
        options[:verbose] = v
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
    @logger.debug("Indexing using config #{@config}")
    collection = MediaFileCollection.new
    persister = AWSPersister.new(
        :ddb => AWS::DynamoDB.new(region:@config['aws']['region']),
        :s3 => AWS::S3.new(region:@config['aws']['region']),
        :file_table_name => @config['db']['file_table'],
        :archive_table_name => @config['db']['archive_table'],
        :bucket_name => @config['s3']['bucket'],
        :archive_prefix => @config['s3']['archive_prefix'],
        :cover_art_prefix => @config['s3']['cover_art_prefix'])

    Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}").each do | file |
      @logger.debug("Adding file #{file} to collection")
      collection.add_file(file)
    end
    collection.dirs.each do | k,v |
      archive = RARArchive.new(@config['local']['rar_path'],
                               @config['local']['archive_dir'],
                               SecureRandom.uuid,
                               "#{File.dirname(k)}/#{File.basename(k)}")
      v.each do | media_file |
        media_file.save do
          persister.save_media_file(media_file)
          @logger.info("Saved media file #{media_file} to table #{@config['db']['file_table']}")
        end

        media_file.write_cover_art do
          key = persister.write_cover_art(media_file)
          @logger.info("Saved cover art with key #{key} to bucket #{@config['s3']['bucket']}")
        end
        archive.add_file(media_file.file)
        @logger.info("Added file #{media_file.file} to archive #{archive.to_s}")
      end
      parts = archive.archive
      @logger.info("Created archive of directory #{k} (#{parts.count} parts/#{parts.inject(0) {|result, part| result + File.size(part)}} total bytes)")
      keys = persister.write_archive(parts)
      @logger.info("Saved archive parts with keys #{keys.join(',')} to bucket #{@config['s3']['bucket']}")
      persister.save_archive(k, keys)
      @logger.info("Saved archive dir #{k} to table #{@config['db']['archive_table']}")
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



require 'logger'
require 'aws-sdk'

module MediaPipeline
  class FileProcessor
    attr_reader :options, :config
    attr_writer :scheduler

    def initialize(options)
      @options = options
      @config = ConfigFile.new(@options[:config]).config
      @logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(@options[:log])
      @logger.level = @options[:verbose] ? Logger::DEBUG : Logger::INFO
      @scheduler = Scheduler.new([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23])  #default to run at all hours of the day
    end

    def process_files
      @logger.debug("Processing using config #{@config}")
      collection = MediaFileCollection.new
      data_access = DAL::AWS::DataAccess.new(DAL::AWS::DataAccessContext.new
                                                        .configure_s3(:s3 => AWS::S3.new(region:@config['aws']['region']),
                                                                      :bucket_name => @config['s3']['bucket'],
                                                                      :archive_prefix => @config['s3']['archive_prefix'],
                                                                      :cover_art_prefix => @config['s3']['cover_art_prefix'])
                                                        .configure_ddb(:ddb => AWS::DynamoDB.new(region:@config['aws']['region']),
                                                                       :file_table_name => @config['db']['file_table'],
                                                                       :archive_table_name => @config['db']['archive_table']))
      concurrency_mgr = ConcurrencyManager.new(@config['s3']['concurrent_connections'].to_i)
      concurrency_mgr.logger = @logger
      data_access.concurrency_mgr = concurrency_mgr

      Dir.glob("#{options[:dir]}/**/*.#{options[:ext]}").each do | file |
        @logger.debug("Adding file #{file} to collection")
        collection.add_file(file)
      end
      collection.dirs.each do | k,v |
        next unless @scheduler.can_execute?
        archive =RARArchive.new(@config['local']['rar_path'],
                                @config['local']['archive_dir'],
                                SecureRandom.uuid,
                                "#{File.basename(File.dirname(k))}/#{File.basename(k)}")
        v.each do | media_file |
          media_file.save do
            data_access.save_media_file(media_file)
            @logger.info("Saved media file #{media_file.file} to table #{@config['db']['file_table']}")
          end

          media_file.write_cover_art do
            key = data_access.write_cover_art(media_file)
            @logger.info("Saved cover art with key #{key} to bucket #{@config['s3']['bucket']}")
          end
          archive.add_file(media_file.file)
          @logger.info("Added file #{media_file.file} to archive #{archive.to_s}")
        end
        parts = archive.archive
        @logger.info("Created archive of directory #{k} (#{parts.count} parts/#{parts.inject(0) {|result, part| result + File.size(part)}} total bytes)")
        keys = data_access.write_archive(parts)
        @logger.info("Saved archive parts with keys #{keys.join(',')} to bucket #{@config['s3']['bucket']}")
        data_access.save_archive(k, keys)
        @logger.info("Saved archive dir #{k} to table #{@config['db']['archive_table']}")
      end
    end
  end
end
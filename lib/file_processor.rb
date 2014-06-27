require 'logger'
require 'aws-sdk'

module MediaPipeline
  class FileProcessor
    attr_reader :config
    attr_writer :scheduler

    def initialize(config, data_access, directory_filter, logger:Logger.new(STDOUT))
      @config = config
      @logger = logger
      @data_access = data_access
      @dir_filter = directory_filter
      @scheduler = Scheduler.new([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23])  #default to run at all hours of the day
    end

    def process_files
      @logger.info(self.class) { LogMessage.new('process_files.start', {config:@config, filter:@dir_filter.to_json}, 'Starting file processing').to_s }
      collection = MediaFileCollection.new

      concurrency_mgr = ConcurrencyManager.new(@config['s3']['concurrent_connections'].to_i)
      concurrency_mgr.logger = @logger
      @data_access.concurrency_mgr = concurrency_mgr

      @dir_filter.filter.each do | file |
        @logger.info(self.class) { LogMessage.new('collection.add_file', file, 'Adding file to collection').to_s }
        collection.add_file(file)
      end
      collection.dirs.each do | k,v |
        next unless @scheduler.can_execute?
        archive =RARArchive.new(@config['local']['rar_path'],
                                @config['local']['archive_dir'],
                                SecureRandom.uuid,
                                "#{File.basename(File.dirname(k))}")
        v.each do | media_file |
          media_file.save do
            @data_access.save_media_file(media_file)
            @logger.info(self.class) { LogMessage.new('data_access.save_media_file', {file:media_file.file, table:@config['db']['file_table']}, 'Saved media file to DynamoDB').to_s}
          end

          media_file.write_cover_art do
            key = @data_access.write_cover_art(media_file)
            @logger.info(self.class) { LogMessage.new('data_access.write_cover_art', {key:key, bucket:@config['s3']['bucket'],file:media_file.file}, 'Wrote cover art to S3').to_s}
          end
          archive.add_file(media_file.file)
          @logger.info(self.class) { LogMessage.new('archive.add_file', {archive_name:archive.archive_name, dir:archive.archive_dir, file:media_file.file}, 'Added file to archive').to_s}
        end

        parts = archive.archive
        size = parts.inject(0) {|result, part| result + File.size(part)}
        @logger.info(self.class) { LogMessage.new('archive.archive', {directory:k, parts:parts, size:size}, 'Created RAR archive')}

        keys = @data_access.write_archive(parts)
        @logger.info(self.class) { LogMessage.new('data_access.write_archive', {keys:keys, bucket:@config['s3']['bucket']}, 'Wrote archive to S3')}

        @data_access.save_archive(k, keys)
        @logger.info(self.class) { LogMessage.new('data_access.save_archive', {keys:keys, archive_key:k, table:@config['db']['archive_table']}, 'Saved archived directory to DynamoDB')}

        @logger.info(self.class) {LogMessage.new('process_files.end', {filter:@dir_filter.to_json}, 'Ending file processing').to_s }
      end
    end
  end
end
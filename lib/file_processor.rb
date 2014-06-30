require 'logger'
require 'aws-sdk'

module MediaPipeline
  class FileProcessor
    attr_reader :config
    attr_writer :scheduler

    def initialize(data_access,
                   directory_filter,
                   archive_context,
                   logger:Logger.new(STDOUT),
                   scheduler:Scheduler.new(Scheduler::ALL))

      @data_access = data_access
      @dir_filter = directory_filter
      @archive_context = archive_context
      @logger = logger
      @scheduler = scheduler
    end

    def process_files
      @logger.info(self.class) { LogMessage.new('process_files.start', {filter:@dir_filter.to_json}, 'Starting file processing').to_s }
      collection = MediaFileCollection.new


      @dir_filter.filter.each do | file |
        @logger.info(self.class) { LogMessage.new('collection.add_file', file, 'Adding file to collection').to_s }
        collection.add_file(file)
      end
      collection.dirs.each do | k,v |
        next unless @scheduler.can_execute?
        archive =RARArchive.new(@archive_context.rar_path,
                                @archive_context.archive_dir,
                                SecureRandom.uuid,
                                "#{File.basename(File.dirname(k))}")
        v.each do | media_file |
          media_file.save do
            @data_access.save_media_file(media_file)
            @logger.info(self.class) { LogMessage.new('data_access.save_media_file', {file:media_file.file, table:@data_access.context.ddb_opts[:file_table_name]}, 'Saved media file to DynamoDB').to_s}
          end

          media_file.write_cover_art do
            key = @data_access.write_cover_art(media_file)
            @logger.info(self.class) { LogMessage.new('data_access.write_cover_art', {key:key, bucket:@data_access.context.s3_opts[:bucket_name],file:media_file.file}, 'Wrote cover art to S3').to_s}
          end
          archive.add_file(media_file.file)
          @logger.info(self.class) { LogMessage.new('archive.add_file', {archive_name:archive.archive_name, dir:archive.archive_dir, file:media_file.file}, 'Added file to archive').to_s}
        end

        parts = archive.archive
        size = parts.inject(0) {|result, part| result + File.size(part)}
        @logger.info(self.class) { LogMessage.new('archive.archive', {directory:k, parts:parts, size:size}, 'Created RAR archive').to_s}

        keys = @data_access.write_archive(parts)
        @logger.info(self.class) { LogMessage.new('data_access.write_archive', {keys:keys, bucket:@data_access.context.s3_opts[:bucket_name]}, 'Wrote archive to S3').to_s}

        @data_access.save_archive(k, keys)
        @logger.info(self.class) { LogMessage.new('data_access.save_archive', {keys:keys, archive_key:k, table:@data_access.context.ddb_opts[:archive_table_name]}, 'Saved archived directory to DynamoDB').to_s}

        #wait for the uploads to complete
        bucket = @data_access.context.s3_opts[:s3].buckets[@data_access.context.s3_opts[:bucket_name]]
        finished = false
        while not finished
          uploaded = keys.select {|key| bucket.objects[key].exists?}.count
          @logger.debug(self.class) {LogMessage.new('wait.upload', {completed:uploaded, remaining:keys.count-uploaded, total:keys.count}, 'Waiting for S3 upload(s) to complete').to_s}
          finished = (uploaded == keys.count)
          sleep 5
        end
        message = @data_access.queue_transcode_task(k)
        @logger.info(self.class) { LogMessage.new('data_access.queue_transcode_task', {message:message}, 'Queued transcode task to SQS').to_s}

        @logger.info(self.class) {LogMessage.new('process_files.end', {filter:@dir_filter.to_json}, 'Ending file processing').to_s }
      end
    end
  end
end
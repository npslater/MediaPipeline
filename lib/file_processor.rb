require 'logger'
require 'aws-sdk'

module MediaPipeline
  class FileProcessor
    attr_reader :config
    attr_writer :scheduler

    def initialize(data_access,
                   archive_context,
                   logger:Logger.new(STDOUT))

      @data_access = data_access
      @archive_context = archive_context
      @logger = logger
    end

    def process_files(directory, files=[])
      @logger.info(self.class) { LogMessage.new('process_files.start', {directory:directory, files:files.map{|media_file| media_file.file}, num_files:files.count}, 'Starting processing files in directory').to_s }

      archive = RARArchive.new(@archive_context.rar_path,
                               @archive_context.archive_dir,
                               SecureRandom.uuid,
                               "#{File.basename(File.dirname(directory))}")
      files.each do | media_file |
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
      @logger.info(self.class) { LogMessage.new('archive.archive', {directory:directory, parts:parts, size:size}, 'Created RAR archive').to_s}

      keys = @data_access.write_archive(parts)
      @logger.info(self.class) { LogMessage.new('data_access.write_archive', {keys:keys, bucket:@data_access.context.s3_opts[:bucket_name]}, 'Wrote archive to S3').to_s}

      @data_access.save_archive(directory, keys)
      @logger.info(self.class) { LogMessage.new('data_access.save_archive', {keys:keys, archive_key:directory, table:@data_access.context.ddb_opts[:archive_table_name]}, 'Saved archived directory to DynamoDB').to_s}

      #wait for the uploads to complete
      bucket = @data_access.context.s3_opts[:s3].buckets[@data_access.context.s3_opts[:bucket_name]]
      finished = false
      while not finished
        uploaded = keys.select {|key| bucket.objects[key].exists?}.count
        @logger.debug(self.class) {LogMessage.new('wait.upload', {completed:uploaded, remaining:keys.count-uploaded, total:keys.count}, 'Waiting for S3 upload(s) to complete').to_s}
        finished = (uploaded == keys.count)
        sleep 5
      end
      message = @data_access.queue_transcode_task(directory)
      @logger.info(self.class) { LogMessage.new('data_access.queue_transcode_task', {message:message}, 'Queued transcode task to SQS').to_s}

      @logger.info(self.class) {LogMessage.new('process_files.end', {directory:directory, files:files.map{|media_file| media_file.file}, num_files:files.count}, 'Ending file processing').to_s }

    end
  end
end
require 'thor'

module MediaPipeline
  class CLI < Thor
    class_option :config, :required=>false, :banner=>'CONFIG FILE', :desc=>'The path to the config file', :default=>'~/.mediapipeline/config'
    class_option :log, :required=>false, :banner=>'LOG FILE', :desc=>'The path to the log file (optional).  If not given, STDOUT will be used'
    class_option :verbose, :required=>false, :desc=>'Verbose logging'

    desc 'process_files', 'Processes the files in the given directory'
    long_desc <<-LONGDESC
      This command performs the following steps:

      1. Search for all the files in the directory specified with the --dir option that match the extension given by the --ext option.

      2. Group the files by their parent directories.

      3. For each file, extract the cover art and store it locally in the location specified by the local:cover_art_dir key in the config file.

      4. Upload each cover art file to the S3 bucket specified by the key s3:bucket in the config file.  The object name is the local file name prepended with the prefix specified by the s3:cover_art_prefix key in the config file.

      5. For each file, create a record in the DynamoDB table specified by the db:file_table key in the config file.  The hash key of the record is the local file path, and the attributes are the ID3 tags, and the s3 URL of the file's cover art.

      6. For each of the parent directories, create a RAR archive using the `rar` command specified by the local:rar_path key in the config file.

      7. Once each RAR archive is complete, upload the RAR archive pieces to the S3 bucket specified by the s3:bucket key in the config file.  The object name for each piece of the archive is the piece name (e.g "archive_1.rar, archive_2.rar, etc") prepended with the prefix specified by the s3:archive_prefix key in the config file.

      8. For each uploaded RAR archive, create a record in the DynamoDB table specified by the db:archive_table key in the config file.  The hash key of the record is the local directory path containing the files included in the archive, and the attributes are the S3 urls to each piece of the RAR archive.

      To make the S3 uploads more efficient, the number of concurrent uploads can be specified using the s3:concurrent_uploads key in the config file.
    LONGDESC

    option :dir, :required=>true, :banner=>'DIR', :desc=>'The directory to index'
    option :ext, :required=>true, :banner=>'EXT', :desc=>'The extension of files to index'
    def process_files
      processor = MediaPipeline::FileProcessor.new(options)
      processor.process_files
    end
  end
end
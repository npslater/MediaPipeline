require 'logger'
require 'TagLib'
require 'securerandom'
require 'open3'

module MediaPipeline

  class TranscodeManager

    def initialize(config:nil, logger:Logger.new(STDOUT), data_access:nil, file_extension:nil)
      @config = config
      @logger = logger
      @data_access = data_access
      @file_extension = file_extension
    end

    def prepare_input(archive_key)
      files = []
      urls = @data_access.fetch_archive_urls(archive_key)
      @logger.info("Fetched archive URLs for #{archive_key}: #{urls}")
      dir = File.join(@config['local']['download_dir'], SecureRandom.uuid)
      Dir.mkdir(dir)
      @logger.info("Created directory to extract archive: #{dir}")
      urls.each do | url |
        file = @data_access.read_archive_object(url, dir)
        files.push(file)
        @logger.info("Downloaded archive file: #{file}")
      end
      cmd = "#{@config['local']['rar_path']} x #{files[0]}"
      @logger.debug("Extracting archive with command #{cmd}")
      Dir.chdir(dir) do
        Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid
          @logger.info("rar process #{pid} started")

          ret = wait_thr.value
          errors = stderr.read
          out = stdout.read

          @logger.info("rar process #{pid} finished with status \"#{ret}\"")
          if errors.length > 0
            @logger.error(errors)
          end
          @logger.debug(out)
        }
      end
      #files = Dir.glob("#{dir}/**/*.#{@options[:ext]}")
      #@data_access.write_transcoder_input(files)
      #download the archives pieces from s3
      #unpack the archive
      #upload the extracted files to the transcode input bucket
      #for each file, submit a job to the ElasticTranscoder pipeline
    end

    def tag_output

    end

  end

end
require 'logger'
require 'TagLib'

module MediaPipeline

  class TranscodeManager

    attr_reader :options, :config, :data_access

    def initialize(options)
      @options = options
      @config = ConfigFile.new(@options[:config]).config
      @logger = options[:log].nil? ? Logger.new(STDOUT) : Logger.new(@options[:log])
      @logger.level = @options[:verbose] ? Logger::DEBUG : Logger::INFO


    end

    def prepare_input(archive_key)
      #download the archives pieces from s3
      #unpack the archive
      #upload the extracted files to the transcode input bucket
      #for each file, submit a job to the ElasticTranscoder pipeline
    end

    def tag_output

    end

  end

end
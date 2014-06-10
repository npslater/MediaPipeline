require 'optparse'
require 'aws-sdk'
require 'logger'
require_relative '../lib/config_file'

class CloudInstaller

  def initialize(config, opts)
    @config = config
    @logger = opts[:log].nil? ? Logger.new(STDOUT) : Logger.new(opts[:log])
    @logger.level = opts[:verbose] ? Logger::DEBUG : Logger::INFO
  end

  def CloudInstaller.parse(args)
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: install_cloud.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"
      opts.on('-c', '--config CONFIG', 'The path to the config file') do | config |
        options[:config] = config
      end
      opts.on('-l', '--logfile FILE', 'The path to the log file.  If not given, messages are written to STDOUT') do | log |
        options[:log] = log
      end
      opts.on('v', '--verbose', 'Use verbose logging') do | verbose |
        options[:verbose] = verbose
      end
    end
    parser.parse!(args)
    missing = [:config].select {|param| options[param].nil?}
    if not missing.empty?
      raise ArgumentError, parser.to_s
    end
    options
  end

  def create_stack
    cfn = AWS::CloudFormation.new(region:@config['aws']['region'])
    cfn.stacks.create(@config['cfn']['stack_name'],
                        File.read('./cfn/aws.json'),
                        :parameters => {
                            'S3BucketName' => @config['s3']['bucket'],
                            'S3ArchivePrefix' => @config['s3']['archive_prefix'],
                            'S3InputPrefix' => @config['s3']['transcode_input_prefix'],
                            'S3OutputPrefix' => @config['s3']['transcode_output_prefix'],
                            'S3CoverArtPrefix' => @config['s3']['cover_art_prefix'],
                            'DDBFileTable' => @config['db']['file_table'],
                            'DDBArchiveTable' => @config['db']['archive_table'],
                            'TranscodeQueueName' => @config['sqs']['transcode_queue'],
                            'ID3TagQueueName' => @config['sqs']['id3tag_queue'],
                            'CloudPlayerUploadQueueName' => @config['sqs']['cloudplayer_upload_queue']

                        })
  end
end

if __FILE__ == $0
  begin
    options = CloudInstaller.parse(ARGV)
    config = ConfigFile.new(options[:config]).config
    installer = CloudInstaller.new(config, options)
    installer.create_stack
  rescue ArgumentError => e
    puts e.message
    exit
  end
end


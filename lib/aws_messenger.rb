require 'aws-sdk'
require 'json'

class AWSMessenger

  def initialize(opts = {})
    required = [:sqs, :transcode_queue_name, :id3_tag_queue_name, :cloudplayer_upload_queue_name]
    missing = required.select { |key| opts[key].nil?}
    if not missing.empty?
      raise ArgumentError, "Missing options: #{missing}"
    end
    @opts = opts
  end

  def queue_transcode_task(archive_urls)
    message = JSON.generate({ urls: archive_urls })
    queue =  @opts[:sqs].queues.named(@opts[:transcode_queue_name])
    puts queue
    queue.send_message(message)
  end

end
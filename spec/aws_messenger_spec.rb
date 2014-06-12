require 'spec_helper'

describe AWSMessenger do
  include AWSHelper

  let!(:config) { ConfigFile.new('./conf/config.yml').config}
  let!(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let(:messenger) {
    AWSMessenger.new(sqs:sqs,
                     transcode_queue_name:config['sqs']['transcode_queue'],
                     id3_tag_queue_name:config['sqs']['id3tag_queue'],
                     cloudplayer_upload_queue_name:config['sqs']['cloudplayer_upload_queue'])
    }

  it 'should return an instance if all the options are set' do
    begin
      messenger = AWSMessenger.new(sqs:sqs,
                                   transcode_queue_name:config['sqs']['transcode_queue'],
                                   id3_tag_queue_name:config['sqs']['id3tag_queue'],
                                   cloudplayer_upload_queue_name:config['sqs']['cloudplayer_upload_queue'])
      expect(messenger).to be_an_instance_of(AWSMessenger)
    rescue ArgumentError => e
      expect(true).to be_falsey
    end
  end

  it 'should queue a transcode task message' do
    urls = %W(s3:#{config['s3']['archive_prefix']}/#{SecureRandom.uuid}.rar s3:#{config['s3']['archive_prefix']}/#{SecureRandom.uuid}.rar)
    messenger.queue_transcode_task(urls)
  end
end
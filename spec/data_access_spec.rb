require 'spec_helper'



describe MediaPipeline::DataAccess do
  include AWSHelper, ArchiveHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', ENV['ENVIRONMENT']).config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }
  let!(:archive_key) { File.dirname(file) }
  let!(:data_access) {
    MediaPipeline::DataAccess.new(
      MediaPipeline::DataAccessContext.new.configure_s3(s3,
                                                        config['s3']['bucket'],
                                                        :archive_prefix => config['s3']['archive_prefix'],
                                                        :cover_art_prefix => config['s3']['cover_art_prefix'],
                                                        :transcode_input_prefix => config['s3']['transcode_input_prefix'],
                                                        :transcode_output_prefix => config['s3']['transcode_output_prefix'])
                                               .configure_ddb(ddb,
                                                              config['db']['file_table'],
                                                              config['db']['archive_table'],
                                                              AWS::DynamoDB::Client.new(api_version:'2012-08-10', region:config['aws']['region']))
                                               .configure_sqs(sqs,
                                                              config['sqs']['transcode_queue'],
                                                              config['sqs']['id3tag_queue'],
                                                              config['sqs']['cloudplayer_upload_queue']))
  }

  before(:all) do
    cleanup_media_file_items
    cleanup_cover_art_objects
    cleanup_archive_objects
    cleanup_local_archives
    cleanup_archive_file_items
    cleanup_transcode_queue
    cleanup_transcode_input_objects
    cleanup_transcode_output_objects
  end

  it 'should return an instance of DataAccess' do
    data_access = MediaPipeline::DataAccess.new(MediaPipeline::DataAccessContext.new)
    expect(data_access).to be_an_instance_of(MediaPipeline::DataAccess)
  end

  it 'should return a hashtable of s3 options' do
    data_access = MediaPipeline::DataAccess.new(MediaPipeline::DataAccessContext.new)
    expect(data_access.context.s3_opts).to be_an_instance_of(Hash)
  end

  it 'should return a hashtable of ddb options' do
    data_access = MediaPipeline::DataAccess.new(MediaPipeline::DataAccessContext.new)
    expect(data_access.context.ddb_opts).to be_an_instance_of(Hash)
  end

  it 'should save a media file to dynamoDB' do
    media_file = MediaPipeline::MediaFile.new(file)
    data_access.save_media_file(media_file)

    #read the item back out and check the attributes
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = [:local_file_path, :string]
    table.range_key = [:local_dir, :string]
    item = table.items.at(File.absolute_path(file), File.dirname(File.absolute_path(file)))
    expect(item).not_to be_nil
    expect(item.attributes['album']).not_to be_nil
  end

  it 'should fetch the dynamoDB item if there is one' do
    item = data_access.fetch_media_file_item(file)
    expect(item.attributes['local_file_path']).to be_instance_of(String)
  end

  it 'should write the cover art to an S3 bucket' do
    media_file = MediaPipeline::MediaFile.new(file)
    key = data_access.write_cover_art(media_file)
    expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to eql(true)
  end

  it 'should write the archive parts to S3' do
      keys = write_archive_parts(config, file, data_access)
      keys.each do | key |
        expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to eql(true)
      end
  end

  it 'should save the archive items to dynamoDB' do
    save_archive(archive_key, config, file, data_access)
    table = ddb.tables[config['db']['archive_table']]
    table.hash_key = :local_dir, :string
    expect(table.items.count).to be > 0
  end

  it 'should queue up a transcode task' do
    data_access.queue_transcode_task(archive_key)
    queue = sqs.queues.named(config['sqs']['transcode_queue'])
    queue.poll(:initial_timeout=>2, :idle_timeout=>2) { |msg| expect(msg.body.include?(archive_key)).to be_truthy }
  end

  it 'should fetch the archive urls from dynamoDB' do
    save_archive(archive_key, config, file, data_access)
    urls = data_access.fetch_archive_urls(archive_key)
    expect(urls.count).to be > 0
  end

  it 'should read the archive from S3 and write it to disk' do
    save_archive(archive_key, config, file, data_access)
    urls = data_access.fetch_archive_urls(archive_key)
    urls.each do | url |
      data_access.read_archive_object(url, config['local']['download_dir'])
    end
  end

  it 'should write an transcoder input file to S3' do
    keys = data_access.write_transcoder_input([file])
    keys.each do | key |
      expect(s3.buckets[config['s3']['bucket']].objects[key].exists?).to be_truthy
    end
  end

  it 'should find the media file item by directory' do
    save_media_file(file, data_access)
    item = data_access.find_media_file_item_by_dir(archive_key, file)
    expect(item).not_to be_nil
  end

  it 'should save the transcode input key' do
    save_media_file(file, data_access)
    item = data_access.save_transcode_input_key(archive_key, "#{MediaPipeline::MediaFile.object_key(config['s3']['transcode_input_prefix'],file)}")
    expect(item.attributes['transcode_input_key']).not_to be_nil
  end

  it 'should find the media file item by transcode input key' do
    save_media_file(file, data_access)
    key =  MediaPipeline.MediaFile.object_key(config['s3']['transcode_input_prefix'],file)
    data_access.save_transcode_input_key(archive_key, key)
    item = data_access.find_media_file_item_by_input_key(key)
    expect(item).not_to be_nil
  end

  it 'should save the transcode output key' do
    save_media_file(file, data_access)
    input_key = MediaPipeline.MediaFile.object_key(config['s3']['transcode_input_prefix'],file)
    data_access.save_transcode_input_key(archive_key, input_key)
    item = data_access.save_transcode_output_key(input_key, MediaPipeline.MediaFile.object_key(config['s3']['transcode_output_prefix'],
                                                                                               File.join(File.dirname(file), "#{File.basename(file, '.m4a')}.mp3")))
    expect(item.attributes['transcode_output_key']).not_to be_nil
  end
end
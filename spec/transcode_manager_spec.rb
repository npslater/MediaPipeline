require 'spec_helper'

describe MediaPipeline::TranscodeManager do
  include AWSHelper, ArchiveHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }
  let!(:mp3_file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.mp3").first }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:sqs) { AWS::SQS.new(region:config['aws']['region'])}
  let!(:transcoder) { AWS::ElasticTranscoder.new(region:config['aws']['region'])}
  let!(:archive_key) { File.dirname(file) }
  let!(:data_access) {
    MediaPipeline::DataAccess.new(
        MediaPipeline::DataAccessContext.new
                                  .configure_s3(s3,
                                                config['s3']['bucket'],
                                                :archive_prefix => config['s3']['archive_prefix'],
                                                :cover_art_prefix => config['s3']['cover_art_prefix'],
                                                :transcode_input_prefix => config['s3']['transcode_input_prefix'],
                                                :transcode_output_prefix => config['s3']['transcode_output_prefix'])
                                  .configure_ddb(ddb,
                                                 config['db']['file_table'],
                                                 config['db']['archive_table'],
                                                 config['db']['stats_table'],
                                                 AWS::DynamoDB::Client.new(api_version:'2012-08-10', region:config['aws']['region']))
                                  .configure_sqs(sqs,
                                                 config['sqs']['transcode_queue'],
                                                 config['sqs']['id3tag_queue'],
                                                 config['sqs']['cloudplayer_upload_queue']))
  }
  let!(:transcode_context) { MediaPipeline::TranscodingContext.new(transcoder, PIPELINES[ENV['ENVIRONMENT']], config['transcoder']['preset_id'], input_ext:'m4a', output_ext:'mp3')}
  let!(:archive_context) { MediaPipeline::ArchiveContext.new(config['local']['rar_path'], config['local']['archive_dir'], config['local']['download_dir'])}
  let!(:transcode_mgr) { MediaPipeline::TranscodeManager.new(data_access, transcode_context, archive_context, logger:Logger.new(STDOUT)) }

  before(:all) do
    cleanup_archive_objects
    cleanup_archive_file_items
    cleanup_transcode_input_objects
    cleanup_transcode_output_objects
    clean_up_stats
  end

  it 'should submit a job to the pipeline' do
    keys = data_access.write_transcoder_input([file])
    begin
      keys.each do | key |
        output_key = "#{File.basename(key, '.m4a')}.mp3"
        transcode_mgr.create_job(key, output_key, data_access.context.s3_opts[:transcode_output_prefix])
      end
    rescue Exception => e
      puts e
      expect(false).to be_truthy
    end
  end

  it 'should prepare the input files to the transcoding pipeline job' do
    save_archive(archive_key, config, file, data_access)
    transcode_mgr.transcode(archive_key)
  end


  it 'should process the transcode output' do
    key = MediaPipeline::ObjectKeyUtils.file_object_key(config['s3']['transcode_input_prefix'], File.basename(file))
    out_key = prepare_transcode_output(key, file, data_access, archive_key, mp3_file)
    transcode_mgr.process_transcoder_output(key, out_key)

  end

end
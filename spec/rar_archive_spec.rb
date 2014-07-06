require 'spec_helper'

describe MediaPipeline::RARArchive do
  include AWSHelper, ArchiveHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let(:files) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a") }

  before(:all) do
    cleanup_local_archives
  end

  it 'should return a instance of RARArchive' do
    archive = MediaPipeline::RARArchive.new('/path/to/rar', '/tmp/archive', 'archive_name', 'dir1/dir2')
    expect(archive).to be_an_instance_of(MediaPipeline::RARArchive)
    expect(archive.archive_dir).to be_an_instance_of(String)
    expect(archive.extract_path).to be_an_instance_of(String)
    expect(archive.archive_name).to be_instance_of(String)
  end

  it 'should add media_files to the archive' do
    archive = MediaPipeline::RARArchive.new('/path/to/rar', '/tmp/archive', 'archive_name', 'dir1/dir2')
    files.each do | file |
      archive.add_file(File.absolute_path(file))
    end
    expect(archive.files.length).to be > 0
  end

  it 'should create a rar archive' do
    collection = MediaPipeline::MediaFileCollection.new
    files.each do | file |
      collection.add_file(file)
    end
    collection.dirs.each do | k, v|
      extract_path = "#{File.basename(File.dirname(k))}/#{File.basename(k)}"
      archive = MediaPipeline::RARArchive.new(config['local']['rar_path'], config['local']['archive_dir'], SecureRandom.uuid, extract_path)
      archive.logger = Logger.new(STDOUT)
      v.each do | media_file |
        archive.add_file(media_file.file)
      end
      parts = archive.archive
      parts.each do | part |
        expect(File.exists?(part)).to be_truthy
      end
    end
  end
end
require_relative 'spec_helper'

describe MediaPipeline::MediaFile do

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', PIPELINES[ENV['ENVIRONMENT']]).config }
  let!(:ddb) { AWS::DynamoDB.new(region:config['aws']['region'])}
  let!(:s3) { AWS::S3.new(region:config['aws']['region'])}
  let!(:file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.m4a").first }
  let!(:mp3_file) { Dir.glob("#{config['local']['media_files_dir']}/**/*.mp3").first }
  let!(:cover_art) {Dir.glob("#{config['local']['cover_art_dir']}/*").first }

  it 'should have a getter for the file property' do
    mf = MediaPipeline::MediaFile.new('/this/is/the/path')
    expect(mf).not_to be_nil
  end

  it 'should return a hash when tag_data is called' do
    mf = MediaPipeline::MediaFile.new(file)
    expect(mf.tag_data).to be_an_instance_of(Hash)
  end

  it 'should return the binary data when cover_art is called' do
    mf = MediaPipeline::MediaFile.new(file)
    expect(mf.cover_art).to be_an_instance_of(String)
  end

  it 'should write the ID3v2 tag data' do
    id = SecureRandom.uuid[0..6]
    tag_data = {
        'artist'=>"artist#{id}",
        'album' => "album#{id}",
        'year' => 2014,
        'title' => "title#{id}",
        'track' => 100,
        'comment' => "comment#{id}",
        'genre' => "genre#{id}",
        'disk' => 200,
        'cover_art' => File.open(cover_art, 'r').read
    }
    media_file = MediaPipeline::MediaFile.new(mp3_file)
    media_file.write_tag(tag_data)
    TagLib::FileRef.open(mp3_file) do | file |
      puts file.tag.artist
      expect(file.tag.artist.eql?(tag_data['artist'])).to be_truthy
      expect(file.tag.album.eql?(tag_data['album'])).to be_truthy
      expect(file.tag.year.eql?(tag_data['year'])).to be_truthy
      expect(file.tag.title.eql?(tag_data['title'])).to be_truthy
      expect(file.tag.track.eql?(tag_data['track'])).to be_truthy
      expect(file.tag.comment.eql?(tag_data['comment'])).to be_truthy
      expect(file.tag.genre.eql?(tag_data['genre'])).to be_truthy
    end
  end
end
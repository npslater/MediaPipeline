require 'Taglib'

class MediaFile

  attr_reader :file

  def initialize(file)
    @file = file
    @tag_data = nil
  end

  def read_tag(file)
    info = nil
    TagLib::FileRef.open(file) do |fileref|
      unless fileref.null?
        tag = fileref.tag
        info = {
            title: tag.title,
            artist: tag.artist,
            album: tag.album,
            year: tag.year,
            track: tag.track,
            genre: tag.genre,
            comment: tag.comment
        }
      end
    end
    TagLib::MP4::File.open(file) do |mp4|
      frame = mp4.tag.item_list_map['disk']
      unless frame.nil?
        info[:disk] = frame.to_int
      end
      cover_art_list = mp4.tag.item_list_map['covr'].to_cover_art_list
      cover_art = cover_art_list.first
      info[:cover_art] = cover_art.data
    end
    info
  end

  def tag_data
    if @tag_data.nil?
      @tag_data = read_tag(@file)
    end
    @tag_data
  end
end
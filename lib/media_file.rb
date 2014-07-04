require 'taglib'
require 'securerandom'

module MediaPipeline
  class MediaFile

    attr_reader :file

    def initialize(file)
      @file = file
      @tag_data = nil
      @cover_art = nil
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
      if file.include?('m4a')
        TagLib::MP4::File.open(file) do |mp4|
          frame = mp4.tag.item_list_map['disk']
          unless frame.nil?
            info[:disk] = frame.to_int
          end
          cover_art_list = mp4.tag.item_list_map['covr'].to_cover_art_list
          cover_art = cover_art_list.first
          @cover_art = cover_art.data
        end
      end
      info
    end

    def tag_data
      if @tag_data.nil?
        @tag_data = read_tag(@file)
      end
      @tag_data
    end

    def cover_art
      if @cover_art.nil?
        @tag_data = read_tag(@file)
      end
      @cover_art
    end

    def write_tag(tag_data={})

      if @file.include?('mp3')
        TagLib::MPEG::File.open(@file) do | file |
          tags = [file.id3v2_tag(true), file.id3v1_tag(true)]
          tags.each do | tag |
            tag.album = tag_data['album']
            tag.artist = tag_data['artist']
            tag.comment = tag_data['comment']
            tag.title = tag_data['title']
            tag.genre = tag_data['genre']
            tag.year = tag_data['year']
            tag.track = tag_data['track']
          end

          #now do the ID3v2 stuff
          if tags[0].frame_list('APIC').count < 1
            apic = TagLib::ID3v2::AttachedPictureFrame.new
            tags[0].add_frame(apic)
          end
          apic =  tags[0].frame_list('APIC').first
          apic.picture = tag_data['cover_art']
          apic.mime_type = 'image/jpeg'
          apic.description = 'Cover'
          apic.type = TagLib::ID3v2::AttachedPictureFrame::FrontCover


          if tags[0].frame_list('TPOS').count < 1
            tpos = TagLib::ID3v2::UserTextIdentificationFrame.new('TPOS')
            tags[0].add_frame(tpos)
          end
          tpos = tags[0].frame_list('TPOS').first
          tpos.text = tag_data['disk'].to_s

          file.save
        end
      end
    end

    def save()
      yield
    end

    def write_cover_art()
      yield
    end
  end
end
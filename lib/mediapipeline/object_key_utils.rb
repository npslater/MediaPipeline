module MediaPipeline
  class ObjectKeyUtils

    def ObjectKeyUtils.file_object_key(prefix, file_name)
      "#{prefix}#{SecureRandom.uuid[0..6]}/#{file_name}"
    end

    def ObjectKeyUtils.cover_art_object_key(prefix)
      "#{prefix}#{SecureRandom.uuid[0..6]}.jpg"
    end

    def ObjectKeyUtils.archive_object_key(prefix, archive_part)
      "#{prefix}#{archive_part}"
    end
  end
end
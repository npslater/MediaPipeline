module MediaPipeline
  class ProcessingStat
    attr_reader :attribute, :value

    ATTRIBUTES =  [:num_local_files, :size_bytes_local_files,
                  :num_archived_files, :size_bytes_archived_files,
                  :num_transcoded_files, :size_bytes_transcoded_files,
                  :audio_length_transcoded_files, :num_tagged_files, :size_bytes_tagged_files]

    def initialize(attribute, value)
      @attribute = attribute
      @value = value
    end

    def ProcessingStat.num_local_files(value)
      ProcessingStat.new(:num_local_files, value)
    end

    def ProcessingStat.size_bytes_local_files(value)
      ProcessingStat.new(:size_bytes_local_files, value)
    end

    def ProcessingStat.num_archived_files(value)
      ProcessingStat.new(:num_archived_files, value)
    end

    def ProcessingStat.size_bytes_archived_files(value)
      ProcessingStat.new(:size_bytes_archived_files, value)
    end

    def ProcessingStat.num_transcoded_files(value)
      ProcessingStat.new(:num_transcoded_files, value)
    end

    def ProcessingStat.size_bytes_transcoded_files(value)
      ProcessingStat.new(:size_bytes_transcoded_files, value)
    end

    def ProcessingStat.audio_length_transcoded_files(value)
      ProcessingStat.new(:audio_length_transcoded_files, value)
    end

    def ProcessingStat.num_tagged_files(value)
      ProcessingStat.new(:num_tagged_files, value)
    end

    def ProcessingStat.size_bytes_tagged_files(value)
      ProcessingStat.new(:size_bytes_tagged_files, value)
    end
  end
end
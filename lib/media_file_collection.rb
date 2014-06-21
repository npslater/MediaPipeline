module MediaPipeline
  class MediaFileCollection

    attr_reader :dirs

    def initialize
      @dirs = {}
    end

    def add_file(file)
      key = File.dirname(File.absolute_path(file))
      @dirs[key] = [] unless @dirs[key]
      @dirs[key].push(MediaFile.new(File.absolute_path(file)))
    end
  end
end
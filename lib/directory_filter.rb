require 'json'

module MediaPipeline
  class DirectoryFilter

    attr_reader :path, :extension

    def initialize(path, extension)
      @path = path
      @extension = extension
    end

    def filter
      Dir.glob("#{@path}/**/*.#{@extension}")
    end

    def to_s
      to_json
    end

    def to_json
      JSON.generate({path:@path, extension:@extension})
    end
  end
end
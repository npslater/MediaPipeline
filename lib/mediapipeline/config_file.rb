require 'yaml'

module MediaPipeline
  class ConfigFile

    attr_reader :config

    def initialize(path, key)
      @config = YAML.load(File.read(path))[key]
    end
  end
end
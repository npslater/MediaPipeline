require 'yaml'

module MediaPipeline
  class ConfigFile

    attr_reader :config

    def initialize(path)
      context = ENV['ENVIRONMENT'].nil? ? 'production' : ENV['ENVIRONMENT']
      @config = YAML.load(File.read(path))[context]
    end
  end
end
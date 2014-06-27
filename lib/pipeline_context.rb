require 'uri'

module MediaPipeline
  class PipelineContext

    attr_reader :name, :cfn

    def initialize(name, template, cfn)
      @name = name
      @template = template
      @cfn = cfn
    end

    def templateUrl?
      begin
        URI.parse(@template)
      rescue URI::InvalidURIError
        false
      end
      true
    end
  end
end
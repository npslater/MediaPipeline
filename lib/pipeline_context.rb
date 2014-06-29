require 'uri'

module MediaPipeline
  class PipelineContext

    attr_reader :name, :cfn, :params

    def initialize(name, template, cfn, params={})
      @name = name
      @template = template
      @cfn = cfn
      @params = params
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
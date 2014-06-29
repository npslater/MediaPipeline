require 'uri'

module MediaPipeline
  class PipelineContext

    attr_reader :name, :template, :cfn, :transcoder, :params

    def initialize(name, template, cfn, transcoder, params={})
      @name = name
      @template = template
      @cfn = cfn
      @transcoder = transcoder
      @params = params
    end

    def templateUrl?
      begin
        uri = URI.parse(@template)
        return (uri.instance_of?(URI::HTTP) or uri.instance_of?(URI::HTTPS))
      rescue URI::InvalidURIError
        false
      end
      false
    end
  end
end
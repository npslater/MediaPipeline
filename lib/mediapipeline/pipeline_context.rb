require 'uri'

module MediaPipeline
  class PipelineContext

    attr_reader :name, :template, :cfn, :transcoder, :bucket, :params

    def initialize(name, template, cfn, transcoder, bucket, params={})
      @name = name
      @template = template
      @cfn = cfn
      @transcoder = transcoder
      @bucket = bucket
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
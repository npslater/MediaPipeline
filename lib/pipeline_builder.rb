require 'aws-sdk'

module MediaPipeline
  class PipelineBuilder
    attr_reader :context

    def initialize(pipeline_context)
      @context = pipeline_context
    end

    def create
      @context.cfn.stacks.create(@context.name,
                                 @context.templateUrl? ? @context.template : File.read(@context.template),
                                 :parameters => @context.params)
    end
  end
end
require 'aws-sdk'
require 'logger'

module MediaPipeline
  class PipelineBuilder

    FINISHED_STATES = %w(CREATE_COMPLETE ROLLBACK_COMPLETE CREATE_FAILED)

    attr_reader :context

    def initialize(pipeline_context, logger:Logger.new(STDOUT))
      @context = pipeline_context
      @logger = logger
      @seen_events = []
    end

    def process_events(stack_events)
      processed_events = []
      stack_events.each do | event |
        next unless (@seen_events.select {|event_id| event.event_id.eql?(event_id)}).count == 0
        processed_events.push(
            {
                timestamp:event.timestamp,
                resource:event.resource_type,
                resource_status:event.resource_status,
                resource_status_reason:event.resource_status_reason,
                resource_id:event.physical_resource_id
            }
        )
        @seen_events.push(event.event_id)
      end
      processed_events
    end

    def create
      @context.cfn.stacks.create(@context.name,
                                 @context.templateUrl? ? @context.template : File.read(@context.template),
                                 :parameters => @context.params)
      stack = @context.cfn.stacks[@context.name]
      finished = false
      while not finished
        sleep 5
        finished = (FINISHED_STATES.select { | status| stack.status.eql?(status) }).count > 0
        @logger.info(self.class) { MediaPipeline::LogMessage.new('pipeline.create_stack', {events:process_events(stack.events)}, 'Creating CloudFormation stack').to_s}
      end
      stack
    end
  end
end
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

    def create_stack
      @context.cfn.stacks.create(@context.name,
                                 @context.templateUrl? ? @context.template : File.read(@context.template),
                                 :parameters => @context.params)
      stack = @context.cfn.stacks[@context.name]
      finished = false
      while not finished
        sleep 5
        finished = (FINISHED_STATES.select { | status| stack.status.eql?(status) }).count > 0
        events = process_events(stack.events)
        @logger.info(self.class) { MediaPipeline::LogMessage.new('pipeline.create_stack', {events:events}, 'Creating CloudFormation stack').to_s} unless events.count < 1
      end
      stack
    end

    def create_pipeline(role_arn, sns_arn)
      @context.transcoder.client.create_pipeline(name:@context.name,
                                                 role:role_arn,
                                                 input_bucket:@context.bucket,
                                                 output_bucket:@context.bucket,
                                                 notifications:{
                                                     progressing:'',
                                                     completed:sns_arn,
                                                     warning:'',
                                                     error:sns_arn
                                                 })
    end

    def delete_stack(s3, delete_s3_objects)
      bucket = @context.params['S3BucketName']
      if delete_s3_objects
        s3.buckets[bucket].objects.each do | object |
          object.delete
        end
      end
      @logger.warn(self.class) {MediaPipeline::LogMessage.new('pipeline.delete_stack', {pipeline_name: @context.name, bucket: bucket}, 'S3 bucket is not empty and will have to be deleted manually').to_s} unless
          s3.buckets[bucket].objects.count < 1
      @context.cfn.stacks.each do | stack |
        if stack.name.include?(@context.name)
          stack.delete
          @logger.info(self.class) {MediaPipeline::LogMessage.new('pipeline.delete_stack', {pipeline_name: @context.name}, 'Pipeline stack has been deleted').to_s}
        end
      end
    end

    def delete_pipeline(name)
      @context.transcoder.client.list_pipelines[:pipelines].each do | pipeline |
        if pipeline[:name].include?(name)
          @context.transcoder.client.delete_pipeline(id:pipeline[:id])
        end
      end
    end
  end
end
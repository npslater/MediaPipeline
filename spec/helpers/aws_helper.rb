require 'aws-sdk'

module AWSHelper

  def config_file
    MediaPipeline::ConfigFile.new('./conf/config.yml', ENV['ENVIRONMENT']).config
  end

  def cleanup_media_file_items
    config = config_file
    ddb = AWS::DynamoDB.new(region:config['aws']['region'])
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = :local_file_path, :string
    table.range_key = :local_dir, :string
    table.items.each do | item |
      item.delete
    end
  end

  def cleanup_objects(config, prefix)
    s3 = AWS::S3.new(region:config['aws']['region'])
    s3.buckets[config['s3']['bucket']].objects.each do | object |
      if object.key.include?(prefix)
        object.delete
      end
    end
  end

  def cleanup_cover_art_objects
    config = config_file
    cleanup_objects(config, config['s3']['cover_art_prefix'])
  end

  def cleanup_archive_objects
    config = config_file
    cleanup_objects(config, config['s3']['archive_prefix'])
  end

  def cleanup_transcode_input_objects
    config = config_file
    cleanup_objects(config, config['s3']['transcode_input_prefix'])
  end

  def cleanup_transcode_output_objects
    config = config_file
    cleanup_objects(config, config['s3']['transcode_output_prefix'])
  end

  def cleanup_archive_file_items
    config = config_file
    ddb = AWS::DynamoDB.new(region:config['aws']['region'])
    table = ddb.tables[config['db']['archive_table']]
    table.hash_key = :local_dir, :string
    table.items.each do | item |
      item.delete
    end
  end

  def cleanup_stacks(stack_name)
    config = config_file
    cfn = AWS::CloudFormation.new(region:config['aws']['region'])

    #empty the S3 bucket
    config = config_file
    s3 = AWS::S3.new(region:config['aws']['region'])
    if s3.buckets[config['s3']['bucket']].exists?
      s3.buckets[config['s3']['bucket']].objects.each do | object |
        object.delete
      end
    end
    cfn.stacks.each do | stack |
      if stack.name.include?(stack_name)
        stack.delete
      end
    end
  end

  def cleanup_transcode_queue
    config = config_file
    sqs = AWS::SQS.new(region:config['aws']['region'])
    queue = sqs.queues.named(config['sqs']['transcode_queue'])
    queue.poll(:idle_timeout=>2) { |msg| sqs.client.delete_message(queue_url:queue.url, receipt_handle:msg.handle) }
  end

  def cleanup_pipelines(pipeline_name)
    config = config_file
    transcoder = AWS::ElasticTranscoder.new(region:config['aws']['region'])
    transcoder.client.list_pipelines[:pipelines].each do | pipeline |
      if pipeline[:name].include?(pipeline_name)
        transcoder.client.delete_pipeline(id:pipeline[:id])
      end
    end
  end
end
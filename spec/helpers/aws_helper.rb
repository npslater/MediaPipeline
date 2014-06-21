require 'aws-sdk'

module AWSHelper

  def cleanup_media_file_items
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    ddb = AWS::DynamoDB.new(region:config['aws']['region'])
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = :local_file_path, :string
    table.range_key = :local_dir, :string
    table.items.each do | item |
      item.delete
    end
  end

  def cleanup_cover_art_objects
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    s3 = AWS::S3.new(region:config['aws']['region'])
    s3.buckets[config['s3']['bucket']].objects.each do | object |
      if object.key.include?(config['s3']['cover_art_prefix'])
        object.delete
      end
    end
  end

  def cleanup_archive_objects
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    s3 = AWS::S3.new(region:config['aws']['region'])
    s3.buckets[config['s3']['bucket']].objects.each do | object |
      if object.key.include?(config['s3']['archive_prefix'])
        object.delete
      end
    end
  end

  def cleanup_local_archives
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    Dir.glob("#{config['local']['archive_dir']}/*.rar").each do | file |
      File.delete(file)
    end
  end

  def cleanup_archive_file_items
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    ddb = AWS::DynamoDB.new(region:config['aws']['region'])
    table = ddb.tables[config['db']['archive_table']]
    table.hash_key = :local_dir, :string
    table.items.each do | item |
      item.delete
    end
  end

  def clean_up_stacks
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    cfn = AWS::CloudFormation.new(region:config['aws']['region'])

    #empty the S3 bucket
    config = MediaPipeline::ConfigFile.new('./conf/config.yml').config
    s3 = AWS::S3.new(region:config['aws']['region'])
    if s3.buckets[config['s3']['bucket']].exists?
      s3.buckets[config['s3']['bucket']].objects.each do | object |
        object.delete
      end
    end
    cfn.stacks.each do | stack |
      if stack.name.eql?(rspec_stack_name(config['cfn']['stack_name']))
        stack.delete
        print 'Deleting stack...'
        begin
          while stack.status.eql?('DELETE_IN_PROGRESS')
            print '...'
            sleep(2)
          end
        rescue  AWS::CloudFormation::Errors::ValidationError => e
          print 'deleted'
          puts
        end
      end
    end
  end

  def override_for_rspec_cfn_stack(config)
    config['cfn']['stack_name'] = "#{rspec_stack_name(config['cfn']['stack_name'])}"
    config['s3']['bucket'] = "#{config['s3']['bucket']}rspec"
    config['s3']['archive_prefix'] = "#{config['s3']['archive_prefix']}rspec"
    config['s3']['transcode_input_prefix'] = "#{config['s3']['transcode_input_prefix']}rspec"
    config['s3']['transcode_output_prefix'] = "#{config['s3']['transcode_output_prefix']}rspec"
    config['s3']['cover_art_prefix'] = "#{config['s3']['cover_art_prefix']}rspec"
    config['db']['file_table'] = "#{config['db']['file_table']}rspec"
    config['db']['archive_table'] = "#{config['db']['archive_table']}rspec"
    config['sqs']['transcode_queue'] = "#{config['sqs']['transcode_queue']}rspec"
    config['sqs']['id3tag_queue'] = "#{config['sqs']['id3tag_queue']}rspec"
    config['sqs']['cloudplayer_upload_queue'] = "#{config['sqs']['cloudplayer_upload_queue']}rspec"
    config
  end

  def rspec_stack_name(stack_name)
    #change the stack name so it doesn't interfere with the stack required by the other tests
    "#{stack_name}rspec"
  end
end
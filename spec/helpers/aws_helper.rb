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

  def clean_up_stacks(stack_name)
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
      if stack.name.eql?(stack_name)
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
end
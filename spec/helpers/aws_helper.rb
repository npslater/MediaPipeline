require 'aws-sdk'

module AWSHelper

  def cleanup_media_file_items
    config = YAML.load(File.read('./conf/config.yml'))
    ddb = AWS::DynamoDB.new(region:config['aws']['region'])
    table = ddb.tables[config['db']['file_table']]
    table.hash_key = :local_file_path, :string
    table.range_key = :local_dir, :string
    table.items.each do | item |
      item.delete
    end
  end

  def cleanup_cover_art_objects
    config = YAML.load(File.read('./conf/config.yml'))
    s3 = AWS::S3.new(region:config['aws']['region'])
    s3.buckets[config['s3']['bucket']].objects.each do | object |
      if object.key.include?(config['s3']['cover_art_prefix'])
        object.delete
      end
    end
  end

  def cleanup_archive_objects
    config = YAML.load(File.read('./conf/config.yml'))
    s3 = AWS::S3.new(region:config['aws']['region'])
    s3.buckets[config['s3']['bucket']].objects.each do | object |
      if object.key.include?(config['s3']['archive_prefix'])
        object.delete
      end
    end
  end

  def cleanup_local_archives
    config = YAML.load(File.read('./conf/config.yml'))
    Dir.glob("#{config['local']['archive_dir']}/*.rar").each do | file |
      File.delete(file)
    end
  end

  def cleanup_archive_file_items
    config = YAML.load(File.read('./conf/config.yml'))
    ddb = AWS::DynamoDB.new(region:config['aws']['region'])
    table = ddb.tables[config['db']['archive_table']]
    table.hash_key = :local_dir, :string
    table.items.each do | item |
      item.delete
    end
  end
end
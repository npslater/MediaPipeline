module MediaPipeline

  class DataAccessContext

    attr_reader :s3_opts, :ddb_opts, :sqs_opts

    def initialize
      @s3_opts = {}
      @ddb_opts = {}
      @sqs_opts = {}
    end

    def configure_s3(s3, bucket_name, archive_prefix:'/archive', cover_art_prefix:'/cover_art', transcode_input_prefix:'/input', transcode_output_prefix:'/output', tagged_output_prefix:'/tagged')
      @s3_opts[:s3] = s3
      @s3_opts[:bucket_name] = bucket_name
      @s3_opts[:archive_prefix] = archive_prefix
      @s3_opts[:cover_art_prefix] = cover_art_prefix
      @s3_opts[:transcode_input_prefix] = transcode_input_prefix
      @s3_opts[:transcode_output_prefix] = transcode_output_prefix
      @s3_opts[:tagged_output_prefix] = tagged_output_prefix
      self
    end

    def configure_ddb(ddb, file_table_name, archive_table_name, client)
      @ddb_opts[:ddb] = ddb
      @ddb_opts[:file_table_name] = file_table_name
      @ddb_opts[:archive_table_name] = archive_table_name
      @ddb_opts[:client] = client
      self
    end

    def configure_sqs(sqs, transcode_queue_name, id3_tag_queue_name, cloudplayer_upload_queue_name)
      @sqs_opts[:sqs] = sqs
      @sqs_opts[:transcode_queue_name] = transcode_queue_name
      @sqs_opts[:id3_tag_queue_name] = id3_tag_queue_name
      @sqs_opts[:cloudplayer_upload_queue_name] = cloudplayer_upload_queue_name
      self
    end
    end
end
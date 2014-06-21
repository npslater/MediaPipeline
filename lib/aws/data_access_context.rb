module MediaPipeline
  module AWS
    class DataAccessContext

      attr_reader :s3_opts, :ddb_opts, :sqs_opts

      def initialize
        @s3_opts = {}
        @ddb_opts = {}
        @sqs_opts = {}
      end

      def configure_s3(s3:nil, bucket_name:nil, archive_prefix:nil, cover_art_prefix:nil)
        @s3_opts[:s3] = s3
        @s3_opts[:bucket_name] = bucket_name
        @s3_opts[:archive_prefix] = archive_prefix
        @s3_opts[:cover_art_prefix] = cover_art_prefix
        self
      end

      def configure_ddb(ddb:nil, file_table_name:nil, archive_table_name:nil)
        @ddb_opts[:ddb] = ddb
        @ddb_opts[:file_table_name] = file_table_name
        @ddb_opts[:archive_table_name] = archive_table_name
        self
      end

      def configure_sqs(sqs:nil, transcode_queue_name:nil, id3_tag_queue_name:nil, cloudplayer_upload_queue_name:nil)
        @sqs_opts[:sqs] = sqs
        @sqs_opts[:transcode_queue_name] = transcode_queue_name
        @sqs_opts[:cloudplayer_upload_queue_name] = cloudplayer_upload_queue_name
        self
      end
    end
  end
end
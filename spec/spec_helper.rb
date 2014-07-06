require_relative '../lib/media_file'
require_relative '../lib/media_file_collection'
require_relative '../lib/data_access'
require_relative '../lib/data_access_context'
require_relative '../lib/rar_archive'
require_relative '../spec/helpers/aws_helper'
require_relative '../lib/concurrency_manager'
require_relative '../lib/config_file'
require_relative '../lib/file_processor'
require_relative '../lib/scheduler'
require_relative '../lib/pipeline_builder'
require_relative '../lib/pipeline_context'
require_relative '../lib/transcode_manager'
require_relative '../spec/helpers/archive_helper'
require_relative '../lib/directory_filter'
require_relative '../lib/log_message'
require_relative '../lib/archive_context'
require_relative '../lib/transcoding_context'
require_relative '../lib/directory_filter'
require_relative '../lib/object_key_utils'
require 'aws-sdk'
require 'securerandom'
require 'logger'
require 'open3'

ENV['ENVIRONMENT'] = 'development' unless ENV['environment']
PIPELINES = {
    'development' => 'mediapipeline-dev',
    'test' => 'mediapipeline-test',
}
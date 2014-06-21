require_relative '../lib/media_file'
require_relative '../lib/media_file_collection'
require_relative '../lib/aws/data_access'
require_relative '../lib/aws/data_access_context'
require_relative '../bin/index_files'
require_relative '../lib/rar_archive'
require_relative '../spec/helpers/aws_helper'
require_relative '../lib/concurrency_manager'
require_relative '../bin/install_cloud'
require_relative '../lib/config_file'
require 'aws-sdk'
require 'securerandom'
require 'logger'
require 'open3'

ENV['ENVIRONMENT'] = 'development'
require_relative '../lib/media_file'
require_relative '../lib/media_file_collection'
require_relative '../lib/aws_persister'
require_relative '../bin/index_files'
require_relative '../lib/rar_archive'
require_relative '../spec/helpers/aws_helper'
require_relative '../lib/concurrency_manager'
require 'aws-sdk'
require 'securerandom'
require 'logger'
require 'open3'
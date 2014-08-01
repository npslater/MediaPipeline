require_relative '../lib/mediapipeline'
require 'helpers/aws_helper'
require 'helpers/archive_helper'
require 'aws-sdk'
require 'securerandom'
require 'logger'
require 'open3'

ENV['ENVIRONMENT'] = 'development' unless ENV['environment']
PIPELINES = {
    'development' => 'mediapipeline-dev',
    'test' => 'mediapipeline-test',
}
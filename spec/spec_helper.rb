require_relative '../lib/media_file'
require 'aws-sdk'

config = YAML.load(File.read('./conf/config.yml'))

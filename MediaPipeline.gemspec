# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mediapipeline/version'

Gem::Specification.new do |spec|
  spec.name          = 'mediapipeline'
  spec.version       = MediaPipeline::VERSION
  spec.authors       = ['Nate Slater']
  spec.email         = ['nateslate@gmail.com']
  spec.summary       = %q{A media file processing pipeline}
  spec.description   = %q{An AWS pipeline for archiving local media files into S3 and transcoding them to MP3 using ElasticTranscoder}
  spec.homepage      = 'http://github.com/npslater/MediaPipeline'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk'
  spec.add_dependency 'taglib-ruby'
  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-rspec'
end

require 'spec_helper'

describe MediaPipeline::PipelineBuilder do
  include AWSHelper

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml').config }
  let!(:cfn) { AWS::CloudFormation.new(region:config['aws']['region'])}

  before(:all) do
    ENV['ENVIRONMENT'] = 'test'
    cleanup_stacks('RSpecPipeline')
  end

  it 'should create the pipeline' do
    builder = MediaPipeline::PipelineBuilder.new({:name=>'RSpecPipeline', :config=>'./conf/config.yml', :verbose=>true, :template=>'./cfn/aws.json'})
    stack = builder.create
    expect(stack.status).to be == 'CREATE_IN_PROGRESS'
  end
end
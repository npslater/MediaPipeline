require 'spec_helper'

describe CloudInstaller do
  include AWSHelper

  let!(:config) { ConfigFile.new('./conf/config.yml').config }
  let!(:cfn) { AWS::CloudFormation.new(region:config['aws']['region'])}

  before(:all) do
    clean_up_stacks
  end

  it 'should create the cloudformation stack' do
    override_cfg = override_for_rspec_cfn_stack(config)
    installer = CloudInstaller.new(override_cfg, {verbose:true})
    stack = installer.create_stack
    expect(stack.status).to be == 'CREATE_IN_PROGRESS'
  end
end
require 'spec_helper'

describe MediaPipeline::TranscodingContext do

  let!(:config) { MediaPipeline::ConfigFile.new('./conf/config.yml', ENV['ENVIRONMENT']).config}
  let!(:transcoder) { AWS::ElasticTranscoder.new(region:config['aws']['region'])}
  let(:context) { MediaPipeline::TranscodingContext.new(transcoder,
                                                        config['transcoder']['pipeline_name'],
                                                        config['transcoder']['preset_id'],
                                                        input_ext:'flac',
                                                        output_ext:config['transcoder']['output_file_ext'])}

  it 'should return a transcoding client' do
   expect(context.transcoder).to be_an_instance_of(AWS::ElasticTranscoder)
  end

  it 'should return a pipeline name' do
    expect(context.pipeline_name.eql?(config['transcoder']['pipeline_name'])).to be_truthy
  end

  it 'should return a preset_id' do
    expect(context.preset_id.eql?(config['transcoder']['preset_id'])).to be_truthy
  end

  it 'should return an input extension' do
    expect(context.input_ext.eql?('flac')).to be_truthy
  end

  it 'should return an output extension' do
    expect(context.output_ext.eql?(config['transcoder']['output_file_ext'])).to be_truthy
  end

end
require 'spec_helper'

describe MediaPipeline::ProcessingStat do

  it 'should create the num_local_files stat' do
    stat = MediaPipeline::ProcessingStat.num_local_files(0)
    expect(stat.attribute).to be == :num_local_files
    expect(stat.value).to be == 0
  end

  it 'should create the size_bytes_local_files stat' do
    stat = MediaPipeline::ProcessingStat.size_bytes_local_files(0)
    expect(stat.attribute).to be == :size_bytes_local_files
    expect(stat.value).to be == 0
  end

  it 'should create the num_archived_files stat' do
    stat = MediaPipeline::ProcessingStat.num_archived_files(0)
    expect(stat.attribute).to be == :num_archived_files
    expect(stat.value).to be == 0
  end

  it 'should create the size_bytes_archived_files stat' do
    stat = MediaPipeline::ProcessingStat.size_bytes_archived_files(0)
    expect(stat.attribute).to be == :size_bytes_archived_files
    expect(stat.value).to be == 0
  end

  it 'should create the num_transcoded_files stat' do
    stat = MediaPipeline::ProcessingStat.num_transcoded_files(0)
    expect(stat.attribute).to be == :num_transcoded_files
    expect(stat.value).to be == 0
  end

  it 'should create the size_bytes_transcoded_files stat' do
    stat = MediaPipeline::ProcessingStat.size_bytes_transcoded_files(0)
    expect(stat.attribute).to be == :size_bytes_transcoded_files
    expect(stat.value).to be == 0
  end

  it 'should create the num_tagged_files stat' do
    stat = MediaPipeline::ProcessingStat.num_tagged_files(0)
    expect(stat.attribute).to be == :num_tagged_files
    expect(stat.value).to be == 0
  end

  it 'should create the size_bytes_tagged_files stat' do
    stat = MediaPipeline::ProcessingStat.size_bytes_tagged_files(0)
    expect(stat.attribute).to be == :size_bytes_tagged_files
    expect(stat.value).to be == 0
  end

  it 'should create the audio_length_transcoded_files stat' do
    stat = MediaPipeline::ProcessingStat.audio_length_transcoded_files(0)
    expect(stat.attribute).to be == :audio_length_transcoded_files
    expect(stat.value).to be == 0
  end


end
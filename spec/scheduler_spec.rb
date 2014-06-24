require 'spec_helper'

describe MediaPipeline::Scheduler do

  it 'should return true if scheduled to run in the current hour of the day' do
    hour = Time.now.hour
    scheduler = MediaPipeline::Scheduler.new([hour])
    expect(scheduler.can_execute?).to be_truthy
  end

  it 'should return false if not scheduled to run in the current hour of the day' do
    hour = Time.now.hour
    hours = []
    (0..8).each do
      if hour == 23
        hour = 0
      end
      hour = hour + 1
      hours.push(hour)
    end
    scheduler = MediaPipeline::Scheduler.new(hours)
    expect(scheduler.can_execute?).to be_falsey
  end

end
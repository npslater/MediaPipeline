module MediaPipeline
  class Scheduler
    attr_reader :hours_in_day

    def initialize(hours_in_day =[])
      @hours_in_day = hours_in_day
    end

    def can_execute?
      hours = @hours_in_day.select { | hour | Time.now.hour.eql?(hour) }
      not hours.empty?
    end
  end
end
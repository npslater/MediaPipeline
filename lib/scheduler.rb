module MediaPipeline
  class Scheduler
    attr_reader :hours_in_day

    ALL = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]

    def initialize(hours_in_day =[])
      @hours_in_day = hours_in_day
    end

    def can_execute?
      hours = @hours_in_day.select { | hour | Time.now.hour.eql?(hour) }
      not hours.empty?
    end
  end
end
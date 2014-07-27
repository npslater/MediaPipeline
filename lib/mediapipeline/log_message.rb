require 'json'

module MediaPipeline
  class LogMessage

    def initialize(event_name, event_data, message)
      @entry = {event: event_name,
                data: event_data,
                message: message}
    end

    def to_s
      to_json
    end

    def to_json
      JSON.generate(@entry)
    end
  end
end
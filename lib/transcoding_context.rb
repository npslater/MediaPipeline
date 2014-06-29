module MediaPipeline
  class TranscodingContext

    attr_reader :transcoder, :pipeline_name, :preset_id, :input_ext, :output_ext

    def initialize(transcoder, pipeline_name, preset_id, input_ext:'m4a', output_ext:'mp3')
      @transcoder = transcoder
      @pipeline_name = pipeline_name
      @preset_id = preset_id
      @input_ext = input_ext
      @output_ext = output_ext
    end
  end
end
require 'open3'

module MediaPipeline
  class RARArchive

    attr_reader :files, :archive_dir, :archive_name, :extract_path, :rar_path
    attr_writer :logger

    def initialize(rar_path, archive_dir, archive_name, extract_path)
      @files = []
      @archive_name = archive_name
      @extract_path = extract_path
      @archive_dir = archive_dir
      @rar_path = rar_path
      @logger = nil
    end

    def add_file(file)
      @files.push "\"#{File.absolute_path(file)}\""
    end

    def archive
      raise ArgumentError, "#{@archive_dir} does not exist" unless Dir.exists?(@archive_dir)
      file_list = @files.join(' ')
      cmd = "rar a -v400m -m1 -rr3% -ep -ap\"#{@extract_path}\" #{archive_dir}/#{archive_name}.rar #{file_list}"
      Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
        pid = wait_thr.pid
        @logger.info("rar process #{pid} started") unless @logger.nil?

        ret = wait_thr.value
        errors = stderr.read
        out = stdout.read

        @logger.info("rar process #{pid} finished with status \"#{ret}\"") unless @logger.nil?
        if errors.length > 0
          @logger.error(errors) unless @logger.nil?
        end
        @logger.debug(out) unless @logger.nil?
      }
      #ret = system(cmd)
      #if ret != 0
      #  @logger.error("rar command failed: #{cmd}") unless not @logger
      #end
      Dir.glob("#{@archive_dir}/#{@archive_name}*.rar")
    end

    def to_s
      "[archive_dir=#{archive_dir},archive_name=#{archive_name},extract_path=#{extract_path},num_files=#{@files.count}]"
    end
  end
end
class ConcurrencyManager

  attr_reader :num_concurrent
  attr_writer :logger

  def initialize(num_concurrent)
    @num_concurrent = num_concurrent
    @pids = []
    @logger = nil
  end

  def run_async &blk
    while @pids.count >= @num_concurrent
      @logger.debug("waiting: #{@pids.count} processes, #{@num_concurrent} allowed") unless @logger.nil?
      pid, status = Process.wait2
      @pids.delete(pid)
    end
    @pids.push(fork { yield })
    @logger.debug("pids: #{@pids}") unless @logger.nil?
  end

end
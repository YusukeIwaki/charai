module Charai
  class BrowserProcess
    def initialize(*command)
      stdin, @stdout, @stderr, @thread = Open3.popen3(*command, { pgroup: true })
      stdin.close
      @pid = @thread.pid
    rescue Errno::ENOENT => err
      raise LaunchError.new("Failed to launch browser process: #{err}")
    end

    def kill
      Process.kill(:KILL, @pid)
    rescue Errno::ESRCH
      # already killed
    end

    def dispose
      [@stdout, @stderr].each { |io| io.close unless io.closed? }
      @thread.terminate
    end

    attr_reader :stdout, :stderr
  end
end

require "open3"
require "shellwords"

class AzureVmVpn
  def initialize(verbose: false)
    @verbose = verbose
    stdin, stdout, @wait_thread = Open3.popen2e("proxy-vps")
    stdout.each do |line|
      break if line.include?("Connected to server")
    end
  end

  def kill
    Process.kill("INT", wait_thread.pid)
  end

  private

  attr_reader :wait_thread
end

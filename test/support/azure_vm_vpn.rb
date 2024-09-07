require 'open3'
require 'shellwords'

class AzureVmVpn
  def initialize verbose: false
    @verbose = verbose
    stdin, stdout, @wait_thread = Open3.popen2e("proxy-vps")
  end

  def kill
    Process.kill("KILL", wait_thread.pid)
  end

  private

  attr_reader :wait_thread
end

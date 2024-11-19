require "open3"
require "shellwords"

class Azurite
  def initialize(verbose: false)
    @verbose = verbose
    stdin, stdout, @wait_thread = Open3.popen2e("azurite")
    stdout.each do |line|
      break if line.include?("Azurite Blob service is successfully listening at http://127.0.0.1:10000")
    end
  end

  def kill
    Process.kill("INT", wait_thread.pid)
  end

  private

  attr_reader :wait_thread
end

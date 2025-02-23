require "open3"
require "net/ssh"
require "shellwords"

class AppServiceVpn
  HOST = "127.0.0.1"

  attr_reader :header, :endpoint

  def initialize(verbose: true)
    @verbose = verbose
    establish_vpn_connection
  end

  def kill
    Process.kill("INT", tunnel_wait_thread.pid)
    Process.kill("INT", connection_wait_thread.pid)
  end

  private

  def establish_vpn_connection
    establish_app_service_tunnel
    extract_msi_info

    puts "Establishing VPN connection..."

    tunnel_stdin, tunnel_stdout, @tunnel_wait_thread = Open3.popen2e([ "sshuttle", "-e", "ssh -o PubkeyAuthentication=no -o CheckHostIP=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null", "-r", "#{username}:#{password}@#{HOST}:#{port}", "0/0" ].shelljoin)

    connection_successful = false
    tunnel_stdout.each do |line|
      puts "(sshuttle) #{line}" if verbose
      if line.include?("Connected to server")
        connection_successful = true
        puts "Connection successful!"
        break
      end
    end

    raise "Could not establish VPN connection to app service" unless connection_successful
  end

  def establish_app_service_tunnel
    puts "Establishing tunnel connection to app service..."
    connection_stdin, connection_stdout, @connection_wait_thread = Open3.popen2e("bin/start-app-service-ssh")

    port = nil
    username = nil
    password = nil

    connection_stdout.each do |line|
      puts "(start-app-service-ssh) #{line}" if verbose
      if line =~ /WARNING: Opening tunnel on port: (\d+)/
        port = $1.to_i
      end

      if line =~ /WARNING: SSH is available \{ username: (\w+), password: ([^\s]+) \}/
        username = $1
        password = $2
      end

      if port && username && password
        break
      end
    end

    raise "Could not establish tunnel connection to app service" unless port && username && password
    @port = port
    @username = username
    @password = password
  end

  def extract_msi_info
    puts "Extracting MSI endpoint info..."
    endpoint = nil
    header = nil
    Net::SSH.start(HOST, username, password:, port:, encryption: 'aes256-ctr', hmac: 'hmac-sha1-96', auth_methods: ['password']) do |ssh|
      endpoint = ssh.exec! [ "bash", "-l", "-c", %(printf "%s" "$IDENTITY_ENDPOINT") ].shelljoin
      header = ssh.exec! [ "bash", "-l", "-c", %(printf "%s" "$IDENTITY_HEADER") ].shelljoin
    end
    raise "Could not extract MSI endpoint information" unless endpoint && header
    @endpoint = endpoint
    @header = header
  end

  attr_reader :port, :username, :password, :verbose, :tunnel_wait_thread, :connection_wait_thread
end

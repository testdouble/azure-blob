require "open3"
require "net/ssh"
require "shellwords"

class AksVpn
  HOST = "127.0.0.1"
  TOKEN_FILE_PATH = "/tmp/azure-identity-token"

  attr_reader :header, :endpoint, :client_id, :tenant_id, :token_file

  def initialize(verbose: true)
    @verbose = verbose
    establish_vpn_connection
  end

  def kill
    Process.kill("INT", tunnel_wait_thread.pid) if tunnel_wait_thread
    Process.kill("INT", port_forward_wait_thread.pid) if port_forward_wait_thread
  end

  private

  def establish_vpn_connection
    setup_kubeconfig
    setup_port_forward
    extract_workload_identity_token

    puts "Establishing VPN connection..."

    tunnel_stdin, tunnel_stdout, @tunnel_wait_thread = Open3.popen2e([ "sshuttle", "-e", "ssh -o CheckHostIP=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null", "--python=python3", "-r", "#{username}@#{HOST}:#{port}", "0/0" ].shelljoin)

    connection_successful = false
    tunnel_stdout.each do |line|
      puts "(sshuttle) #{line}" if verbose
      if line.include?("Connected to server")
        connection_successful = true
        puts "Connection successful!"
        break
      end
    end

    raise "Could not establish VPN connection to AKS" unless connection_successful
  end

  def setup_kubeconfig
    puts "Setting up kubectl config..."
    resource_group = `terraform output --raw resource_group`.strip
    cluster_name = `terraform output --raw aks_cluster_name`.strip

    system("az aks get-credentials --resource-group #{resource_group} --name #{cluster_name} --overwrite-existing --only-show-errors 2>/dev/null")
    raise "Failed to setup kubectl config" unless $?.success?

    # Wait for pod to be ready
    puts "Waiting for SSH pod to be ready..."
    system("kubectl wait --for=condition=ready pod -l app=azure-blob-test --timeout=300s")
    raise "Pod did not become ready" unless $?.success?
  end

  def setup_port_forward
    puts "Setting up port forward to SSH service..."

    @username = `terraform output --raw aks_ssh_username`.strip

    @port = 2222

    system("lsof -ti:#{@port} | xargs kill -9 2>/dev/null")

    # Use kubectl port-forward to forward to the LoadBalancer service
    # This is more reliable than waiting for the external IP to be routable
    port_forward_stdin, port_forward_stdout, @port_forward_wait_thread = Open3.popen2e("kubectl port-forward service/azure-blob-test-ssh #{@port}:22")

    # Wait for port forward to be established and read confirmation
    port_forward_ready = false
    Thread.new do
      port_forward_stdout.each do |line|
        port_forward_ready = true if line.include?("Forwarding from")
      end
    end

    # Wait up to 10 seconds for port forward
    10.times do
      break if port_forward_ready
      sleep 1
    end

    raise "Port forward did not establish" unless port_forward_ready

    puts "Port forward established on port #{@port}"
  end

  def extract_workload_identity_token
    puts "Extracting workload identity token from pod..."

    max_retries = 5
    retry_count = 0

    begin
      Net::SSH.start(HOST, username, port:, auth_methods: [ "publickey" ]) do |ssh|
        token = ssh.exec! "cat /var/run/secrets/azure/tokens/azure-identity-token"
        File.write(TOKEN_FILE_PATH, token.strip)
      end

      @client_id = `terraform output --raw aks_workload_identity_client_id`.strip
      @tenant_id = `terraform output --raw azure_tenant_id`.strip
      @token_file = TOKEN_FILE_PATH

      puts "Wrote token to #{TOKEN_FILE_PATH}"
    rescue Net::SSH::AuthenticationFailed, Errno::ECONNREFUSED => e
      retry_count += 1
      if retry_count < max_retries
        puts "SSH connection failed (attempt #{retry_count}/#{max_retries}), retrying in 2 seconds..."
        sleep 2
        retry
      else
        raise "Could not extract workload identity token after #{max_retries} attempts: #{e.message}"
      end
    end
  end

  attr_reader :port, :username, :verbose, :tunnel_wait_thread, :port_forward_wait_thread
end

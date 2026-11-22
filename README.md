# AzureBlob

Azure Blob client and Active Storage adapter to replace the now abandoned azure-storage-blob

An Active Storage is supplied, but the gem is Rails agnostic and can be used in any Ruby project.

Requires Ruby 3.3 or newer. The Active Storage service supports Rails 8.0 or newer.

## Active Storage

### Migration
To migrate from azure-storage-blob to azure-blob:

1. Replace `azure-storage-blob` in your Gemfile with `azure-blob`
2. Run `bundle install`
3. Change the `AzureStorage` service to `AzureBlob`  in your Active Storage config (`config/storage.yml`)
4. Restart or deploy the app.

Example config:

```
microsoft:
  service: AzureBlob
  storage_account_name: account_name
  storage_access_key: SECRET_KEY
  container: container_name
```

### Managed Identity (Entra ID)

AzureBlob supports managed identities on:
- Azure VM
- App Service
- AKS (Azure Kubernetes Service) with workload identity
- Azure Functions (Untested but should work)
- Azure Containers (Untested but should work)

To authenticate through managed identities instead of a shared key, omit `storage_access_key` from your `storage.yml` file and pass in the identity `principal_id`.

ActiveStorage config example:

```
prod:
  service: AzureBlob
  container: container_name
  storage_account_name: account_name
  principal_id: 71b34410-4c50-451d-b456-95ead1b18cce
```

#### User delegation key expiration

When authenticating through Entra ID, signed URLs are signed with a user delegation key
that AzureBlob requests and renews as needed. `delegation_key_expiration` (in seconds)
sets how long each key lasts: 7 hours by default, up to Azure's maximum of 7 days. Set it
above the longest URL lifetime your app issues.

```ruby
client = AzureBlob::Client.new(
  account_name: "account_name",
  container: "container_name",
  principal_id: "71b34410-4c50-451d-b456-95ead1b18cce",
  delegation_key_expiration: 86400, # 1 day
)
```

ActiveStorage config example:

```
prod:
  service: AzureBlob
  container: container_name
  storage_account_name: account_name
  principal_id: 71b34410-4c50-451d-b456-95ead1b18cce
  delegation_key_expiration: 86400 # 1 day
```

The option is ignored when authenticating with a shared key.

#### AKS with Workload Identity

ActiveStorage config example:

```
prod:
  service: AzureBlob
  container: container_name
  storage_account_name: account_name
  use_managed_identities: true
```

> uses `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_FEDERATED_TOKEN_FILE` environment variables, made available by AKS cluster when Azure AD Workload Identity is set up properly.


### Azurite

To use Azurite, pass the `storage_blob_host` config key with the Azurite URL (`http://127.0.0.1:10000/devstoreaccount1` by default)
and the Azurite credentials (`devstoreaccount1` and `Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==` by default).

Example:

```
dev:
  service: AzureBlob
  container: container_name
  storage_account_name: devstoreaccount1
  storage_access_key: "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
  storage_blob_host: http://127.0.0.1:10000/devstoreaccount1
```

You'll have to create the container before you can start uploading files.
You can do so using Azure CLI, Azure Storage Explorer, or by running:

`bin/rails runner "ActiveStorage::Blob.service.client.tap{|client| client.create_container unless client.get_container_properties.present?}.tap { |client| puts 'done!' if client.get_container_properties.present?}"`

Make sure that `config.active_storage.service = :dev` is set to your azurite configuration.
Container names can't have any special characters, or you'll get an error.

## Standalone

Instantiate a client with your account name, an access key and the container name:

```ruby
client = AzureBlob::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: @container,
    )

path = "some/new/file"

# Upload
client.create_block_blob(path, "Hello world!")

# Download
client.get_blob(path) #=> "Hello world!"

# Delete
client.delete_blob(path)
```

For the full list of methods: https://www.rubydoc.info/gems/azure-blob/AzureBlob/Client

## options

### Lazy loading

The client is configured to raise an error early for missing credentials, causing it to crash before becoming healthy. This behavior can sometimes be undesirable, such as during assets precompilation.

To enable lazy loading and ignore missing credentials, set the `lazy` option:

`AzureBlob::Client.new(account_name: nil, access_key: nil, container: nil, lazy: true)`

or add `lazy: true` to your `config/storage.yml` for Active Storage.

### Persistent connections

By default, every request opens a new connection to Azure and closes it afterward. Persistent connections stay open and are reused, which saves a TCP and TLS handshake on every request.

This relies on the [net-http-persistent](https://github.com/drbrain/net-http-persistent) gem, which is not a dependency of azure-blob. Add it to your Gemfile:

```ruby
gem "net-http-persistent"
```

Rails requires it automatically. To use it outside of Rails, set the `persistent_connections` option to `true` on the client:

```ruby
client = AzureBlob::Client.new(
  account_name: "account_name",
  access_key: "SECRET_KEY",
  container: "container_name",
  persistent_connections: true,
)
```

If your app uses net-http-persistent but you do not want azure-blob to use it, set `persistent_connections: false` on the client or in your `config/storage.yml`.

#### Custom connection pool

To tune the connections (pool size, timeouts, etc.), build your own pool and pass it as `connection_pool`:

```ruby
connection_pool = Net::HTTP::Persistent.new(name: "azure-blob", pool_size: 10)
connection_pool.idle_timeout = 30

client = AzureBlob::Client.new(
  account_name: "account_name",
  access_key: "SECRET_KEY",
  container: "container_name",
  connection_pool: connection_pool,
)
```

`connection_pool` also takes a class, or the name of a class, and calls `new` on it. This is how to set a pool from `config/storage.yml`:

```ruby
class BlobConnectionPool < Net::HTTP::Persistent
  def initialize
    super(name: "azure-blob", pool_size: 10)
    self.idle_timeout = 30
  end
end
```

```yaml
microsoft:
  service: AzureBlob
  storage_account_name: account_name
  storage_access_key: SECRET_KEY
  container: container_name
  connection_pool: BlobConnectionPool
```

A pool does not have to be a `Net::HTTP::Persistent`. It can be any object that:

- responds to `request(uri, request)`, where `uri` is a `URI` and `request` a `Net::HTTPRequest`
- returns the `Net::HTTPResponse`
- is safe to call from several threads at once

A `connection_pool` is used whatever `persistent_connections` is set to.


## Contributing

### Dev environment

A dev environment is supplied through Nix with [devenv](https://devenv.sh/).

1. Install [devenv](https://devenv.sh/).
2. Enter the dev environment by cd into the repo and running `devenv shell` (or `direnv allow` if you are a direnv user).
3. Log into azure CLI with `az login`
4. `terraform init`
5. `terraform apply` This will generate the necessary infrastructure on azure.
6. Generate devenv.local.nix with your private key and container information: `generate-env-file`
7. If you are using direnv, the environment will reload automatically. If not, exit the shell and reopen it by hitting <C-d> and running `devenv shell` again.

#### Entra ID

To test with Entra ID, the `AZURE_ACCESS_KEY` environment variable must be unset and the code must be ran or proxied through a VPS with the proper roles.

For cost saving, the terraform variables `create_vm`, `create_app_service`, and `create_aks` are false by default.
To create the VM, App Service, and/or AKS cluster, create a var file `var.tfvars` containing:

```
create_vm = true
create_app_service = true
create_aks = true
```
and re-apply terraform: `terraform apply -var-file=var.tfvars`.

This will create the infrastructure and required managed identities.

**Testing:**
- `bin/rake test_azure_vm` - Establishes a VPN connection to the Azure VM and runs tests using node identity
- `bin/rake test_app_service` - Establishes a VPN connection to the App Service container and runs tests
- `bin/rake test_aks` - Establishes a VPN connection to the AKS cluster and runs tests using workload identity

You might be prompted for a sudo password when the VPN starts (sshuttle).

After you are done, run terraform again without the var file (`terraform apply`) to destroy all resources.

#### Persistent connections

The tests run without persistent connections. To run them with persistent connections: `PERSISTENT_CONNECTIONS=true bin/rake test`

#### Cleanup

Some tests copied over from Rails don't clean after themselves. A rake task is provided to empty your containers and keep cost low: `bin/rake flush_test_container`

#### Run without devenv/nix

If you prefer not using devenv/nix:

Ensure your version of Ruby fit the minimum version in `azure-blob.gemspec`

and setup those Env variables:

- `AZURE_ACCOUNT_NAME`
- `AZURE_ACCESS_KEY`
- `AZURE_PRIVATE_CONTAINER`
- `AZURE_PUBLIC_CONTAINER`

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

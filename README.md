# AzureBlob

Azure Blob client and Active Storage adapter to replace the now abandoned azure-storage-blob

An Active Storage is supplied, but the gem is Rails agnostic and can be used in any Ruby project.

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

AzureBlob supports managed identities on :
- Azure VM
- App Service
- Azure Functions (Untested but should work)
- Azure Containers (Untested but should work)

AKS support will likely require more work. Contributions are welcome.

To authenticate through managed identities instead of a shared key, omit `storage_access_key` from your `storage.yml` file and pass in the identity `principal_id`.

ActiveStorage config example:

```
prod:
  service: AzureBlob
  container: container_name
  storage_account_name: account_name
  principal_id: 71b34410-4c50-451d-b456-95ead1b18cce
```

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

For cost saving, the terraform variable `create_vm` and `create_app_service` are false by default.
To create the VPS and App service, Create a var file `var.tfvars` containing:

```
create_vm = true
create_app_service = true
```
and re-apply terraform: `terraform apply -var-file=var.tfvars`.

This will create the VPS and required managed identities.

`bin/rake test_azure_vm` and `bin/rake test_app_service` will establish a VPN connection to the VM or App service container and run the test suite. You might be prompted for a sudo password when the VPN starts (sshuttle).

After you are done, run terraform again without the var file (`terraform apply`) to destroy the VPS and App service application.

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

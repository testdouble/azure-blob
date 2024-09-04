# AzureBlob

This gem was built to replace azure-storage-blob (deprecated) in Active Storage, but was written to be Rails agnostic.

## Active Storage

## Migration
To migrate from azure-storage-blob to azure-blob:

1. Replace `azure-storage-blob` in your Gemfile with `azure-blob`
2. Run `bundle install`
3. Change the `AzureStorage` service to `AzureBlob`  in your Active Storage config (`config/storage.yml`)
4. Restart or deploy the app.


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
6. Generate devenv.local.nix with your private key and container information: `terraform output -raw devenv_local_nix > devenv.local.nix`
7. If you are using direnv, the environment will reload automatically. If not, exit the shell and reopen it by hitting <C-d> and running `devenv shell` again.

#### Entra ID

To test with Entra ID, the `AZURE_ACCESS_KEY` environment variable must be unset and the code must be ran or proxied through a VPS with the proper roles.

For cost saving, the terraform variable `create_vm` is false by default.
To create the VPS, Create a var file `var.tfvars` containing:

```
create_vm = true
```
and re-apply terraform: `terraform apply -var-file=var.tfvars`.

This will create the VPS and required roles.

Use `proxy-vps` to proxy all network requests through the vps with sshuttle. sshuttle will likely ask for a sudo password.

Then use `bin/rake test_entra_id` to run the tests with Entra ID.

After you are done, running terraform again without the var file (`terraform apply`) it should destroy the VPS.

#### Cleanup

Some test copied over from Rails codebase don't clean after themselves. A rake task is provided to empty your containers and keep cost low: `bin/rake flush_test_container`

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

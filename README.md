# AzureBlob

This gem was built to replace azure-storage-blob (deprecated) in Active Storage, but was written to be Rails agnostic.

## Active Storage

## Migration
To migrate from azure-storage-blob to azure-blob:

1. Replace `azure-storage-blob` in your Gemfile with `azure-blob`
2. Run `bundle install`
3. Change the `AzureStorage` service to `AzureBlob`  in your Active Storage config (`config/storage.yml`)
4. Restart or deploy the app.

## Authenricate using Managed Identity

Get an access token for Azure Storage from the  the local Managed Identity endpoint.
```bash
curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true
```

Now use the access token to access Azure Storage.
```bash
curl 'https://<STORAGE ACCOUNT>.blob.core.windows.net/<CONTAINER NAME>/<FILE NAME>' -H "x-ms-version: 2017-11-09" -H "Authorization: Bearer <ACCESS TOKEN>"
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

Ensure your version of Ruby fit the minimum version in `azure-blob.gemspec`

and setup those Env variables:

- `AZURE_ACCOUNT_NAME`
- `AZURE_ACCESS_KEY`
- `AZURE_PRIVATE_CONTAINER`
- `AZURE_PUBLIC_CONTAINER`


A dev environment setup is also supplied through Nix with [devenv](https://devenv.sh/).

To use the Nix environment:
1. install [devenv](https://devenv.sh/)
2. Copy `devenv.local.nix.example` to `devenv.local.nix`
3. Insert your azure credentials into `devenv.local.nix`
4. Start the shell with `devenv shell` or with [direnv](https://direnv.net/).

### Tests

`bin/rake test`

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

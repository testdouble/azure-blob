# AzureBlob

This gem was built to replace azure-storage-blob (deprecated) in Active Storage, but was written to be Rails agnostic.

## Active Storage

## Migration
To migrate from azure-storage-blob to azure-blob:

1. Replace `azure-storage-blob` in your Gemfile with `azure-blob`
2. Run `bundle install`
3. Change the `AzureStorage` service to `AzureBlob`  in your Active Storage config (`config/storage.yml`)
4. Restart or deploy the app.


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

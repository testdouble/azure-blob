# AzureBlob

This gem was built to replace azure-storage-blob (deprecated) in Active Storage, but was written to be Rails agnostic.


# Active Storage

## Migration
To migrate from azure-storage-blob to azure-blob:

1- Replace `azure-storage-blob` in your Gemfile with `azure-blob`
2- Run `bundle install`
3- change the `AzureStorage` service to `AzureBlob`  in your Active Storage config (`config/storage.yml`)
4- Restart or deploy the app.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

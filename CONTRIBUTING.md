# Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/testdouble/azure-blob).

## Running lint and the tests

All you need is Docker. The tests run against [Azurite](https://github.com/Azure/Azurite), Microsoft's local Azure Storage emulator, so you don't need an Azure account.

```
docker compose run lint
docker compose run test
```

The first run builds the image and installs the gems, which takes a few minutes. After that, gems are only reinstalled when the Gemfile changes. Add `--rm` to remove the container after each run.

To run a single file or test:

```
docker compose run test bundle exec m test/client/test_client.rb
docker compose run test bundle exec m test/client/test_client.rb:41
```

The full run creates the test containers in Azurite, so run `docker compose run test` once before running single tests. Azurite keeps running in the background after a run, with its data in memory. Stop it with `docker compose down`.

## What Azurite doesn't cover

Azurite doesn't implement every Azure API (Put Blob From URL, for example) and has no Entra ID (managed identity) support, so some tests are skipped there. Before merging, a maintainer runs the full suite on your commit against real Azure, including the managed identity tests on an Azure VM, App Service and AKS.

The `client_test` and `rails_test` checks on a pull request run against the maintainers' Azure account. They need repository secrets, so they fail on pull requests from forks. The `lint` and `azurite_test` checks need no secrets and should pass.

## Running against your own Azure account (optional)

If you have an Azure storage account, you can run the suite against it with Ruby installed locally. Create a private container and a container with anonymous blob read access, then:

```
export AZURE_ACCOUNT_NAME=your_account
export AZURE_ACCESS_KEY=your_access_key
export AZURE_PRIVATE_CONTAINER=your_private_container
export AZURE_PUBLIC_CONTAINER=your_public_container
bundle install
bundle exec rake test
```

The [README](README.md#contributing) covers the full maintainer setup with devenv and Terraform, including the managed identity tests.

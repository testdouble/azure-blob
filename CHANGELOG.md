## [Unreleased]

- Validate blob name length against Azure's limits

## [0.5.8] 2025-05-14

- Add support for copying blobs across containers (#24)

## [0.5.7.1] 2025-04-22

- Fixed a bug when reusing the account name in the container name. #22

## [0.5.7] 2025-02-21

- Add `copy_blob`
- Update `compose` to use `copy_blob` if 1 source key and blob is <= 256MiB

## [0.5.6] 2025-01-17

- Fix user delegation key not refreshing (#14)

## [0.5.5] 2025-01-10

- Allow lazy loading the signer
- Add `blob_exist?`
- Add `container_exist?`

## [0.5.4] 2024-11-18

- Allow creating public container
- Add Azurite support

## [0.5.3] 2024-10-31

- Add support for setting tags when uploading a blob
- Add get_blob_tags

## [0.5.2] 2024-09-12

- Add get_container_properties
- Add create_container
- Add delete_container
- Support for Azure China, US Gov and Germany

## [0.5.1] 2024-09-09

- Remove dev files from the release

## [0.5.0] 2024-09-09

- Added support for Managed Identities (Entra ID)

## [0.4.2] 2024-06-06

- Documentation
- Fix an issue with integrity check on multi block upload


## [0.4.1] 2024-05-27

First working release.

- Re-implemented the required parts of the azure-storage-blob API to make Active Storage work.
- Extracted the AzureStorage adapter from Rails.

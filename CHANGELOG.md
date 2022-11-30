# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [2.2.8]
- Fix tests by using Postgres 14
- i18n - pulling from tx
- Sync locale Makefile from plugin template
- Pin GitHub actions to a major version
- Bump actions/setup-node from 3.5.0 to 3.5.1
- Bump actions/checkout from 2.4.0 to 3.1.0
- Bump actions/setup-node from 3.4.1 to 3.5.0

## [2.2.7]
- Fix unit tests - remove 2.4 -develop and ruby 2.5
- Fixes #35495 - Replace Foreman to_bool with rails implementation
- Bump actions/setup-node from 2.5.0 to 3.4.1
- Fixes #35481 - Remove hard coded sudo command in script extension
- Bump actions/setup-node from 2.4.1 to 2.5.0

## [2.2.6]
- Bump actions/setup-node from 2.1.5 to 2.2.0
- Fixes #32713 - Add Cloud validation to controller
- Bump actions/setup-node from 2.2.0 to 2.3.0
- Fixes #33159 - Add support for tags on Azure VM resources
- Bump actions/setup-node from 2.3.0 to 2.3.1
- Bump actions/setup-node from 2.3.1 to 2.3.2
- Bump actions/checkout from 2.3.4 to 2.4.0
- Bump actions/setup-node from 2.3.2 to 2.4.1

## [2.2.5]
- Bump actions/checkout from 2 to 2.3.4
- Bump actions/setup-node from 2 to 2.1.5
- Fixes #32639 - Fix nil error when editing a Windows VM
- Fixes #32640 - Implement Azure Extension Microsoft.HpcCompute/NvidiaGpuDriver{Linux,Windows}/1.3 to deploy NVIDIA GPU drivers
- Refs #32640 - Use Microsoft name (the one used when created from Azure interface) for NVIDIA GPU extension
- i18n - pulling from tx
- Fixes #32693 - Fix Grammar and update screenshots on README

## [2.2.4]
- Fixes #32526 - don't mark compute profile password as required
- Fixes #32555 - default to public "azure" cloud if not specified
- Refs #32120 - drop Windows from limitations
- Fixes #32561 - use "cloud" in the CR API output

## [2.2.3]
- Fixes #32500 - Use Foreman::Cast.to_bool to parse private_ip

## [2.2.2]
- Fixes #32128 - move to GitHub Actions
- Ruby 2.7 support

## [2.2.1]
- Enable windows type vm
- Implement custom size for OS disk
- Drop deface dependency

## [2.2.0]
- Fixes #31188 - Add support for gov-cloud
- Fixes #31837 - Add plugin doc button to main form
- Fixes #31188 - Remove Gov Cloud from planned features in README
- Fixes #31837 - fix syntax error in azurerm.html.erb

## [2.1.3]
- Fixes #31837 - Add plugin doc button to main form
- Fixes #31837 - fix syntax error in azurerm.html.erb

## [2.1.2]
- Fixes #30291 - Add vm creation tests
- Fixes #30379 - i18n pulling from tx

## [2.1.1]
- Correct syntax highlighting in README
- Fixes #29844 - pull from tx, add missing tx file, version 2.1.0
- Fixes #29819 - Support byos images on azurerm
- Update Readme.md for 2.1.x
- Fixes #30027 - Cannot read property 'aDataSort' of undefined

## [2.1.0]
- Fixes #28790 - Add Volumes capability
- Fixes #27407 - Custom Image and Shared Image Gallery support
- Refs #27407 - Check Image of type AzureRm for validating
- Fixes #29222 - Dynamically load regions based on subscription
- Fixes #29501 - Add Internationalization support
- Fixes #29586 - Move Travis to postgres
- Fixes #29629 - Refactor Test Connection for AzureRm
- Fixes #29688 - Support Rails 5 and 6 for test matrix

## [2.0.8]
- Fixes #29109 - Host edit fails for sshkey with script

## [2.0.7]
- Fixes #28972 - Migration to fix casing to AzureRm
- Fixes #27364 - Added missing supported Azure Regions
- Refs #28972 - Add db/migrate directory to engine

## [2.0.6]
- Fixes #28162 - Custom script, file uris and image_id get blank
- Fixes #28772 - OS disk caching should be default ReadWrite
- Fixes #28814 - Unable to click VM under CRs page
- Fixes #26499 - VM properties widget is overlapping

## [2.0.5]
- Display correct messages
- Fixes #28625 - Compute attributes set from CLI not shown on UI
- Move travis to ruby 2.5 to avoid dependency error
- Fixes #28690 - Modify README.md to latest

## [2.0.4]
- Renaming to support better snake_case

## [2.0.3]
- Fixes #28172 - No validation for region in CR create
- Fixes #28404 - Import managed and unmanaged hosts
- Fixes #28390 - Host not created with static private IP
- Fixes #27622 - Image password gets blank on edit
- Fixes #28438 - Undefined method reload for PowerOn/Off
- Fixes #28456 - Compute Profile VM attributes column blank
- Fixes #28469 - No validation for public ip in cli
- Fixes #28470 - Start checkbox of Power ON doesn't work

## [2.0.2]
- Uninitialized constant ForemanAzureRM::AzureSDKAdapter

## [2.0.1]
- Adding API params for CLI
- Fixing Edit values and defining region on the Compute Resource instead of VM.

## [2.0.0.pre1]
- Making changes for ForemanAzureRM with azure-sdk-for-ruby
  - Integrated with Azure-sdk-for-ruby
  - Removed dependency on fog/fog-azure-rm
  - Provisioning support using Foreman's finish and user data templates
  - Supports single NIC and single (default) OS disk
- Upate README.md with azure-sdk changes
- Update gem mocha as development dependency

## [1.3.1]
### Fixed
- Changelog unreleased hyperlink
- Remove unused overrides and associated assets
## [1.3.0]
### Added
- /compute_resources/:id/:region_id/available_sizes endpoint to list all sizes in an Azure region
- /compute_resources/:id/available_subnets endpoint to list all subnets
- /compute_resources/:id/available_vnets endpoint to list available vnets with complete information
### Fixed
- Apply .freeze to version constant
- Changelog hyperlink for to compare v1.1.1 to v1.2.0
## [1.2.0]
### Added
- This changelog
- RABL template for API compute resource view
- available_networks api endpoint
- UUID to GET compute_resources/:id endpoint
- Added an API call (/compute_resources/:id/available_resource_groups) to retrieve resource groups
- Available_networks API endpoint now returns all subnets in the subscription
### Fixed
- This changelog
- Use correct custom script extension for Windows hosts

## [1.1.1] - 2017-05-11
### Fixed
- Failure on nil os_profile

## [1.0.0] - 2017-04-05
### Fixed
- Numerous errors (I can't rememeber)
### Changed
- Improved stability

## 0.1.0 - 2017-03-21
### Added
- Initial release

[1.3.1]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.0.0...v1.1.1
[1.0.0]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v0.1.0...v1.0.0

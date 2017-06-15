# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
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


[Unreleased]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v1.0.0...v1.1.1
[1.0.0]: https://github.com/01100010011001010110010101110000/foreman_azure_rm/compare/v0.1.0...v1.0.0

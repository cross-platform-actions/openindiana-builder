# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- Increase the disk to 24 GB, so `pkg` has room to install build dependencies
    ([action#172](https://github.com/cross-platform-actions/action/issues/172))
- Remove the 2 GB swap volume, which took space from the root file system
- Remove downloaded packages after a successful `pkg install`

## [0.0.1] - 2026-11-23
### Added
- Initial release
- Support for OpenIndiana 2026.10.30

[Unreleased]: https://github.com/cross-platform-actions/openindiana-builder/compare/v0.0.1...HEAD

[0.0.1]: https://github.com/cross-platform-actions/openindiana-builder/releases/tag/v0.0.1

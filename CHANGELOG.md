# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-08-21

### Added

- Support for alpinelinux/unbound container as alternative to mvance/unbound

### Changed

- Container image from mvance/unbound to alpinelinux/unbound
- Volume mount paths updated for Alpine Linux filesystem layout
- Docker-compose configuration simplified

## [1.0.0] - 2025-03-01

### Added

- Initial Pi-hole + Unbound configuration using mvance/unbound
- Documentation for setup and configuration

[unreleased]: https://github.com/kaczmar2/pihole-unbound/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/kaczmar2/pihole-unbound/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/kaczmar2/pihole-unbound/releases/tag/v1.0.0

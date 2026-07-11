# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- README: recommended blocklist upgrade step (Hagezi Multi Pro via the web
  interface); SSL guide is now Step 8.

## [3.0.0] - 2026-07-10

### Added

- Optional `WEBSERVER_PASSWORD` variable in `.env` for the
  environment-variable password method (`FTLCONF_webserver_api_password`).
- README: explicit "Start the Containers" step.

### Changed

- **Password setup**: the recommended method is now a one-time
  `docker exec pihole pihole setpassword 'mypassword'`, which persists in the
  bind-mounted `pihole.toml`. The environment-variable method uses the
  plaintext `FTLCONF_webserver_api_password` (hashed by FTL at startup),
  matching the upstream docker-pi-hole documentation.
- `unbound.conf` trimmed from ~390 lines to only the settings that differ
  from Unbound's compiled-in defaults. Effective configuration is unchanged
  (verified with `unbound-checkconf`) except:
  - Cache sizing reduced to home-network scale: `msg-cache-size`
    142 MB → 16 MB, `rrset-cache-size` 285 MB → 32 MB.
  - Removed unused datacenter tuning (`num-queries-per-thread`,
    `outgoing-range`) and settings that were silently overridden by
    `unbound.conf.d/10-pi-hole.conf` (`num-threads`, `use-caps-for-id`,
    `verbosity`, `logfile`).
  - A few options reverted to compiled defaults: `neg-cache-size` (1 MB),
    `do-not-query-localhost` (yes), and removal of unused `identity` /
    `http-user-agent` strings and `tls-cert-bundle`.

### Removed

- `set-password.sh` and the `WEBSERVER_PWHASH` /
  `FTLCONF_webserver_api_pwhash` workflow. It existed to work around the
  env-overrides-toml behavior; both new methods make it unnecessary.

### Migration from 2.x

Existing deployments keep working without changes:
`FTLCONF_webserver_api_pwhash` remains a valid Pi-hole env var. To adopt the
new scheme, remove the `FTLCONF_webserver_api_pwhash` line from
`docker-compose.yml` and `WEBSERVER_PWHASH` from `.env`, restart
(`docker compose down && docker compose up -d`), then run
`docker exec pihole pihole setpassword 'mypassword'`.

Note: re-extracting the release tarball overwrites `.env` and
`docker-compose.yml` with the new templates — re-apply your local values
(e.g. `TZ`) afterward.

## [2.1.0] - 2025-08-26

### Added

- Automated setup script `set-password.sh` to configure your Pi-hole admin password.

### Changed

- `WEBSERVER_PWHASH` variable naming in `.env` for consistency.

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

[unreleased]: https://github.com/kaczmar2/pihole-unbound/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/kaczmar2/pihole-unbound/compare/v2.1.0...v3.0.0
[2.1.0]: https://github.com/kaczmar2/pihole-unbound/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/kaczmar2/pihole-unbound/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/kaczmar2/pihole-unbound/releases/tag/v1.0.0

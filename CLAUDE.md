# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A public baseline Docker Compose setup for Pi-hole v6 + Unbound (recursive DNS), published at github.com/kaczmar2/pihole-unbound. There is no build system, linter, or test suite — the deliverables are `docker-compose.yml`, the Unbound config files, and the README itself. End users download a tarball of `main` and run it on their own hosts, so `main` must always be in a usable state.

## Commands

```bash
docker compose up -d          # start the stack
docker compose down           # stop it
docker exec pihole pihole setpassword 'pw'   # set admin password (persists in bind-mounted pihole.toml)
docker logs pihole            # container logs (also: docker logs unbound)

# Verify Unbound works (run inside the pihole container):
docker exec -it pihole dig pi-hole.net @127.0.0.1 -p 5335
docker exec -it pihole dig fail01.dnssec.works @127.0.0.1 -p 5335   # expect SERVFAIL (DNSSEC validation)
docker exec -it pihole dig dnssec.works @127.0.0.1 -p 5335          # expect NOERROR
```

## Architecture

Two containers, one network namespace:

- **pihole** (`pihole/pihole`) owns the network stack, exposing ports 53/80/443. Configured entirely via `FTLCONF_*` environment variables sourced from `.env`. Persistent data lives in a bind mount at `/srv/docker/pihole-unbound/pihole/etc-pihole` (host paths in `docker-compose.yml` assume this convention).
- **unbound** (`alpinelinux/unbound`) runs with `network_mode: service:pihole`, so it shares Pi-hole's network namespace and is not exposed to the host. Pi-hole forwards upstream queries to `127.0.0.1#5335` (`FTLCONF_dns_upstreams`).

Unbound config layering: `unbound-config/unbound.conf` (general/performance/security settings) ends with a wildcard include of `unbound-config/unbound.conf.d/*.conf`. Files there load in lexical order — hence the numeric prefixes — and for single-value options the last occurrence wins:

- `10-pi-hole.conf` — the settings from the official Pi-hole Unbound guide, including the actual listener (`interface: 127.0.0.1`, `port: 5335`).
- `20-private-domains.conf` — `private-domain` exceptions for services that legitimately resolve public names to private IPs (e.g. `plex.direct` for Plex).

`unbound.conf` deliberately contains only settings that differ from Unbound's compiled-in defaults; `10-pi-hole.conf` is a verbatim copy of the official Pi-hole guide config — don't edit it, so it stays diffable against upstream. Verify any effective value with `docker exec unbound unbound-checkconf -o <option>`.

## Key Constraints

- **Pi-hole v6 env vars override `pihole.toml` and become read-only.** That's why the README recommends a one-time `pihole setpassword` (persists in the bind-mounted `pihole.toml`) and keeps `FTLCONF_webserver_api_password` commented out as the declarative alternative. Never make an `FTLCONF_*` var the default for something users are told to change at runtime.
- `.env` is committed intentionally as a template with safe defaults (commented-out `WEBSERVER_PASSWORD`); don't gitignore it or commit a real password.
- `CHANGELOG.md` follows Keep a Changelog / Semantic Versioning — record notable changes under `[Unreleased]`.
- Versions and tags exist for the runtime files users download and run (`docker-compose.yml`, the Unbound configs). Docs-only changes (README links, wording) land directly on `main` with no version bump or CHANGELOG entry; only notable doc rewrites go under `[Unreleased]`. Prefer linking to stable URLs the user controls (e.g., the `pihole-ssl-guide` repo) over gist deep-links with file anchors.
- The README is user-facing setup documentation and the docs of record for this setup; when changing `docker-compose.yml` or the Unbound configs, update the corresponding README section. (The sibling `pihole-docs` repo is a fork of the official Pi-hole docs for upstream PRs — it does not document this setup.)

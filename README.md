# Pi-hole v6 + Unbound in Docker

## Summary

This is a baseline setup of Pi-hole and Unbound with Docker. It assumes that
your router already provides DHCP and NTP. To make Pi-hole serve DHCP, you
must configure it differently.

This setup is based on the official
[Pi-hole Unbound guide](https://docs.pi-hole.net/guides/dns/unbound/). It
adapts the guide for Pi-hole v6 and Docker Compose.

Unbound does not have its own network interface. It uses the network stack of
Pi-hole (`network_mode: service:pihole`). As a result:

- The host network does not expose Unbound. Unbound can still resolve
  recursive DNS queries.
- Pi-hole sends all upstream DNS queries to `127.0.0.1#5335`. Unbound does the
  recursive lookups.
- Unbound needs no other network configuration.

This setup uses the official `alpinelinux/unbound` image. The image gets
regular updates and runs on many platforms, including the Raspberry Pi.

## Contents

- [Prerequisites](#prerequisites)
- [Step 1: Create the Directories for Bind Mounts](#step-1-create-the-directories-for-bind-mounts)
- [Step 2: Download the Repository](#step-2-download-the-repository)
- [Step 3: Set Your Timezone](#step-3-set-your-timezone)
- [Step 4: Start the Containers](#step-4-start-the-containers)
- [Step 5: Set the Pi-hole Admin Password](#step-5-set-the-pi-hole-admin-password)
- [Step 6: Test Unbound](#step-6-test-unbound)
- [Step 7: Open the Pi-hole Web Interface](#step-7-open-the-pi-hole-web-interface)
- [Step 8: Point Your Devices at Pi-hole](#step-8-point-your-devices-at-pi-hole)
- [Step 9: Upgrade the Blocklist](#step-9-upgrade-the-blocklist-recommended)
- [Step 10: Secure the Web Interface With SSL](#step-10-secure-the-web-interface-with-ssl-optional)
- [Unbound Configuration](#unbound-configuration)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before you start, make sure that you have:

- A Debian or Debian-based Linux distribution (Ubuntu, Raspberry Pi OS, and
  other Debian-based distributions)
- [Docker](https://docs.docker.com/engine/install/)
- A static IP address on the host

Your devices point at the static IP address of the host for DNS. If the
address changes, DNS stops working on your network.

## Step 1: Create the Directories for Bind Mounts

Create the directories for the bind mounts before you download the repository.

Run these commands:

```bash
mkdir -p ~/docker/pihole-unbound
sudo mkdir -p /srv/docker/pihole-unbound/pihole/etc-pihole
sudo mkdir -p /srv/docker/pihole-unbound/pihole/etc-dnsmasq.d
sudo chown -R $USER:$USER /srv/docker
chmod -R 755 /srv/docker
cd ~/docker/pihole-unbound
```

### What These Commands Do

- `mkdir -p ~/docker/pihole-unbound`: Creates a working directory in your home
  folder.
- `sudo mkdir -p /srv/docker/...`: Creates the bind mount directories for
  Pi-hole.
- `sudo chown -R $USER:$USER /srv/docker`: Gives your user ownership of the
  folders.
- `chmod -R 755 /srv/docker`: Gives the owner read and write access, and gives
  everyone else read access.
- `cd ~/docker/pihole-unbound`: Moves into the working directory.

Note: Pi-hole needs `etc-dnsmasq.d` only for upgrades from Pi-hole v5. The
volume for it stays commented out in `docker-compose.yml`.

## Step 2: Download the Repository

Download the current version of the repository from the `main` branch:

```bash
curl -L -o main.tar.gz https://github.com/kaczmar2/pihole-unbound/archive/refs/heads/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
rm main.tar.gz
```

The `--strip-components=1` flag puts the files directly into
`~/docker/pihole-unbound`. Without the flag, `tar` creates an extra
subdirectory.

## Step 3: Set Your Timezone

The `.env` file ships with the timezone `America/Denver`. If you do not change
it, Pi-hole shows the wrong times in logs and graphs.

1. Open `.env` in an editor:

   ```bash
   nano .env
   ```

2. Set `TZ` to your own timezone from the
   [tz database list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):

   ```bash
   TZ=America/New_York
   ```

3. Save the file.

Note: The other values in `.env` work for most setups.

## Step 4: Start the Containers

```bash
docker compose up -d
```

Docker pulls the `pihole/pihole` and `alpinelinux/unbound` images. Then Docker
starts both containers.

## Step 5: Set the Pi-hole Admin Password

The web interface needs an admin password. If you set no password, Pi-hole
creates a random one and writes it to the container log. There are two ways to
set your own password.

### Recommended: `pihole setpassword`

Run this command one time in the running container:

```bash
docker exec pihole pihole setpassword 'mypassword'
```

Pi-hole stores the password hash in `/etc/pihole/pihole.toml`. This file lives
in the `/srv/docker/pihole-unbound/pihole/etc-pihole` bind mount. The password
survives container restarts and image upgrades. No password goes into `.env`.
You can change the password later from the web interface, or you can run the
command again.

Note: This command writes the password into your shell history file,
`~/.bash_history`.

### Alternative: Environment Variable

If you prefer to keep the password in your configuration files, use an
environment variable.

1. Set the password in `.env`:

   ```bash
   WEBSERVER_PASSWORD='mypassword'
   ```

2. Uncomment this line in `docker-compose.yml`:

   ```yaml
   FTLCONF_webserver_api_password: ${WEBSERVER_PASSWORD}
   ```

3. Restart the containers:

   ```bash
   docker compose down && docker compose up -d
   ```

**Notes:**

- If you uncomment the `FTLCONF_webserver_api_password` line, set
  `WEBSERVER_PASSWORD` to a non-empty value. An empty value turns off the web
  interface login. It does not create a random password.
- Environment variables lock their settings in Pi-hole v6. While the variable
  is set, you cannot change the password from the web interface or from the
  command line.
- The plaintext password is visible in `.env` and in the output of
  `docker inspect pihole`. The `pihole setpassword` method does not store the
  password in a file.

## Step 6: Test Unbound

These commands run inside the pihole container. Open a shell in the container:

```bash
docker exec -it pihole /bin/bash
```

Make sure that Unbound answers queries:

```bash
dig pi-hole.net @127.0.0.1 -p 5335
```

The first query is slow, because Unbound asks the root servers directly. Later
queries come from the cache and are fast.

Make sure that DNSSEC validation works:

```bash
dig fail01.dnssec.works @127.0.0.1 -p 5335
dig dnssec.works @127.0.0.1 -p 5335
```

The first command gives the status SERVFAIL and no IP address. The second
command gives the status NOERROR and an IP address.

Leave the container shell:

```bash
exit
```

## Step 7: Open the Pi-hole Web Interface

Open this address in your web browser:

```text
http://<your-server-ip>/admin/
```

Log in with the password from Step 5.

## Step 8: Point Your Devices at Pi-hole

Pi-hole blocks nothing until your devices use it for DNS. There are two ways to
do this.

**All devices at the same time.** In your router, set the DNS server that DHCP
gives to clients. Use the static IP address of your Docker host. Then restart
your devices, or wait for the DHCP lease to renew.

**One device at a time.** In the network settings of the device, set the DNS
server to the static IP address of the host.

Note: Router menus differ by brand. The DNS setting is usually under the DHCP
or LAN settings.

## Step 9: Upgrade the Blocklist (Recommended)

Pi-hole uses the [StevenBlack hosts](https://github.com/StevenBlack/hosts) list
by default. The [Hagezi Multi Pro](https://github.com/hagezi/dns-blocklists)
list blocks more ads and trackers. It does not break common websites.

To change the list, open the Pi-hole web interface:

1. Open **Lists**.
2. Add a new entry with the address
   `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt`
   and the comment `Hagezi Multi Pro`.
3. Disable or delete the StevenBlack entry on the same page.
4. Open **Tools > Update Gravity**, then click **Update**.

Hagezi offers lighter and stricter variants (Light, Normal, Pro++, Ultimate).
See the [Hagezi repository](https://github.com/hagezi/dns-blocklists) to choose
a different one.

## Step 10: Secure the Web Interface With SSL (Optional)

See my guides on how to configure SSL for the Pi-hole web interface:

- [Pi-hole v6 SSL Certificates](https://github.com/kaczmar2/pihole-ssl-guide) —
  browser-trusted certificates with an internal CA, or self-signed certificates
- [Pi-hole v6 + Docker: Let's Encrypt with Cloudflare DNS](https://gist.github.com/kaczmar2/027fd6f64f4e4e7ebbb0c75cb3409787) —
  publicly trusted certificates that renew automatically

## Unbound Configuration

The `unbound-config/` directory holds the Unbound configuration. Docker mounts
this directory read-only into the unbound container.

### Configuration Files

- `unbound-config/unbound.conf` — Holds only the settings that change the
  built-in defaults of Unbound. These are the DNSSEC trust anchor, cache sizes
  for home networks, and some hardening options. Everything else uses the
  defaults of Unbound.
- `unbound-config/unbound.conf.d/10-pi-hole.conf` — Configures Unbound for
  Pi-hole. This file is a copy of the configuration from the
  [Pi-hole Unbound guide](https://docs.pi-hole.net/guides/dns/unbound/).
- `unbound-config/unbound.conf.d/20-private-domains.conf` — Lists domains that
  can resolve to private IP addresses. It includes `plex.direct`, which Plex
  clients use to connect to a local server.

### Notes

- Unbound reads all files in `unbound-config/unbound.conf.d/`. A wildcard
  include directive in `unbound.conf` loads them.
- The files load in alphabetical order. For a setting with one value, the last
  file wins.
- To see the value that Unbound uses for a setting, run
  `docker exec unbound unbound-checkconf -o <option>`.
- To allow another service that resolves private IP addresses, add it to
  `20-private-domains.conf`.

## Maintenance

### Update the Containers

Run these commands to get the newest images:

```bash
docker compose pull
docker compose up -d
```

Your Pi-hole data stays in the bind mount. Settings and query history survive
the update.

### Check the Logs

```bash
docker logs pihole
docker logs unbound
```

## Troubleshooting

### Port 53 Is Already in Use

On Ubuntu and recent Debian versions, `systemd-resolved` listens on port 53.
Docker cannot bind the port, and `docker compose up -d` fails with an error
about the address already in use.

1. Find the process that holds the port:

   ```bash
   sudo ss -tulpn | grep ':53'
   ```

2. If the process is `systemd-resolved`, turn off its stub listener:

   ```bash
   sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
   ```

3. Point `/etc/resolv.conf` at the real resolver file:

   ```bash
   sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   ```

4. Restart the service:

   ```bash
   sudo systemctl restart systemd-resolved
   ```

5. Start the containers again:

   ```bash
   docker compose up -d
   ```

### Fix the `so-rcvbuf` Warning in Unbound (Optional)

`10-pi-hole.conf` sets a large socket receive buffer for incoming DNS queries.
The large buffer prevents lost messages during traffic spikes.

You can see this warning in the unbound logs:

```text
so-rcvbuf 1048576 was not granted. Got 425984. To fix: start with root permissions(linux)
or sysctl bigger net.core.rmem_max(linux)
or kern.ipc.maxsockbuf(bsd) values.
```

Run these commands on the host system:

1. Read the current limit:

   ```bash
   sudo sysctl net.core.rmem_max
   ```

   The command shows a value such as `net.core.rmem_max = 425984`.

2. Raise the limit for the current session:

   ```bash
   sudo sysctl -w net.core.rmem_max=1048576
   ```

3. To keep the limit after a reboot, add this line to `/etc/sysctl.conf`:

   ```bash
   net.core.rmem_max=1048576
   ```

4. Apply the file:

   ```bash
   sudo sysctl -p
   ```

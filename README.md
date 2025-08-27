# Pi-hole v6 + Unbound in Docker

## Summary

This is a **baseline setup of Pi-hole and Unbound** using Docker. It assumes
that you already have a gateway/router with a **separate DHCP and NTP server**.
If you want Pi-hole to handle DHCP, additional configuration is needed.

This setup follows the official **[Pi-hole Unbound guide](https://docs.pi-hole.net/guides/dns/unbound/)**
but adapts it for **Pihole v6 and Docker Compose**.

In this setup, **Unbound does not have its own network interface**; instead, it
runs using **Pi-hole’s network stack** (`network_mode: service:pihole`). This means:

- **Unbound is not exposed to the host network** but can still resolve recursive DNS queries.
- **Pi-hole forwards all upstream DNS queries** to `127.0.0.1#5335`, where Unbound handles recursive lookups.
- **No additional networking configurations are needed** for Unbound.

This setup uses the official `alpinelinux/unbound` Docker image, which provides
better security, regular updates, and cross-platform compatibility (including 
Raspberry Pi).

## Prerequisites

Before you begin, ensure you are running:

- A **Debian or Debian-based Linux distribution** (Ubuntu, Raspberry Pi OS, etc.)
- [**Docker** installed](https://docs.docker.com/engine/install/)

## Step 1: Create the Directory Structure for Bind Mounts

Before downloading the repository, set up the necessary directories for your
**bind mounts**.

Run the following commands:

```bash
mkdir -p ~/docker/pihole-unbound
sudo mkdir -p /srv/docker/pihole-unbound/pihole/etc-pihole
sudo mkdir -p /srv/docker/pihole-unbound/pihole/etc-dnsmasq.d
sudo mkdir -p /srv/docker/pihole-unbound/unbound/etc-unbound
sudo chown -R $USER:$USER /srv/docker
chmod -R 755 /srv/docker
touch /srv/docker/pihole-unbound/unbound/etc-unbound/unbound.log
cd ~/docker/pihole-unbound
```

### What These Commands Do

- `mkdir -p ~/docker/pihole-unbound`: Creates a working directory in your home folder.
- `sudo mkdir -p /srv/docker/...`: Creates **bind mounts** for Pi-hole and Unbound.
- `sudo chown -R $USER:$USER /srv/docker`: Ensures **your user owns the folders**.
- `chmod -R 755 /srv/docker`: Sets **read/write permissions** for better access.
- `touch unbound.log`: Prepares the **log file for Unbound**.

## Step 2: Download the Repository

Download the latest version of the repository:

```bash
curl -L -o main.tar.gz https://github.com/kaczmar2/pihole-unbound/archive/refs/heads/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
```

The `--strip-components=1` flag ensures the contents are extracted directly
into `~/docker/pihole-unbound` instead of creating an extra subdirectory.

**Note**: This setup uses the official `alpinelinux/unbound` Docker image,
which provides better security, regular updates, and cross-platform
compatibility (including Raspberry Pi).

## Step 3: Set the Pi-hole Admin Password

### Automated Setup

Use the automated setup script to configure your Pi-hole admin password:

```bash
./setup-password.sh
```

This script will:

- Prompt you securely for a password
- Temporarily disable the password environment variable in docker-compose.yml
- Set the password in the Pi-hole container (writes to pihole.toml)
- Extract and save the password hash to your `.env` file
- Re-enable the password environment variable in docker-compose.yml
- Restart containers with the new configuration
- Create backups of your config files

Your Pi-hole admin interface will be ready with the password you set.

### Manual Setup

If you prefer the manual approach or need to troubleshoot:

<details>
<summary>Click to expand manual setup instructions</summary>

**Important**: For Pi-hole v6, environment variables override the TOML file.
You must temporarily comment out the password environment variable to allow
the TOML file to be updated.

1. Comment out `FTLCONF_webserver_api_pwhash` in `docker-compose.yml`:

   ```yaml
   # FTLCONF_webserver_api_pwhash: ${WEBSERVER_PWHASH}
   ```

2. Restart containers to apply the change:

   ```bash
   docker compose down && docker compose up -d
   ```

3. Set your password in the Pi-hole container:

   ```bash
   docker exec -it pihole /bin/bash
   pihole setpassword 'mypassword'
   ```

4. Get the hashed password from `pihole.toml`:

   ```bash
   cat /etc/pihole/pihole.toml | grep -E "^[[:space:]]*pwhash[[:space:]]*="
   exit
   ```

5. Copy the hash value and add it to your `.env` file (enclose in single quotes):

   ```bash
   WEB_PWHASH='$BALLOON-SHA256$v=1$s=1024,t=32$pZCbBIUH/Ew2n144eLn3vw==$vgej+obQip4DvSmNlywD0LUHlsHcqgLdbQLvDscZs78='
   ```

6. Uncomment the `FTLCONF_webserver_api_pwhash` environment variable in `docker-compose.yml`:

   ```yaml
   FTLCONF_webserver_api_pwhash: ${WEB_PWHASH}
   ```

7. Restart the containers:

   ```bash
   docker compose down && docker compose up -d
   ```

</details>

## Step 4: Verify Unbound Is Working

To confirm Unbound is resolving queries correctly, run the following commands
**in the pihole container**:

Open a `bash` shell in the container:

```bash
docker exec -it pihole /bin/bash
```

Test that Unbound is operational:

```bash
dig pi-hole.net @127.0.0.1 -p 5335
```

The first query may be quite slow, but subsequent queries should be fairly quick.

Test validation:

```bash
dig fail01.dnssec.works @127.0.0.1 -p 5335
dig dnssec.works @127.0.0.1 -p 5335
```

The first command should give a status report of SERVFAIL and no IP address. The
second should give NOERROR plus an IP address.

## Step 5: Access the Pi-hole Web Interface

Once running, open your web browser and go to:

```bash
http://<your-server-ip>/admin/
```

Login using the password you set.

## Step 6: Secure Web Interface With SSL (Optional)

For enhanced security, see my other guides on **configuring SSL encryption** for
the Pi-hole web interface.

- [Pi-hole v6 + Docker: Automating Let's Encrypt SSL Renewal with Cloudflare DNS](https://gist.github.com/kaczmar2/027fd6f64f4e4e7ebbb0c75cb3409787#file-pihole-v6-docker-le-cf-md)

## Common Issues & Troubleshooting

### Fix `so-rcvbuf` warning in Unbound (Optional)

The configuration in `pi-hole.conf` sets the **socket receive buffer size** for
incoming DNS queries to a higher-than-default value in order to handle high
query rates.

You may see this warning in unbound logs:

```bash
so-rcvbuf 1048576 was not granted. Got 425984. To fix: start with root permissions(linux)
or sysctl bigger net.core.rmem_max(linux) 
or kern.ipc.maxsockbuf(bsd) values.
```

To fix it, **run these commands on the host system**:

1. Check the current limit. This will show something like `net.core.rmem_max = 425984`:

    ```bash
    sudo sysctl net.core.rmem_max
    ```

2. Temporarily increase the limit to match Unbound's request:

    ```bash
    sudo sysctl -w net.core.rmem_max=1048576
    ```

3. Make it permanent. Edit `/etc/sysctl.conf` and add or edit the line:

    ```bash
    net.core.rmem_max=1048576
    ```

4. Save and apply:

    ```bash
    sudo sysctl -p
    ```

## Check Docker logs

This will show logs for both the `pihole` and `unbound` containers.

```bash
docker logs pihole
docker logs unbound
```

## Unbound Custom Configuration

The `unbound.conf.d/` directory contains custom configuration settings for Unbound.

### Configuration Files

- **`unbound.conf.d/`** _(Custom Unbound settings, automatically included via a wildcard in `unbound.conf`.)_
  - **`10-pi-hole.conf`** – Configures Unbound for use with Pi-hole following the [Pi-hole Unbound guide](https://docs.pi-hole.net/guides/dns/unbound/).
  - **`20-private-domains.conf`** – Adds exceptions for domains that resolve private IPs from public DNS servers.
    - Includes an entry for `plex.direct`, required for Plex clients to connect to the local server.
    - Additional entries may be needed for other services that rely on domain-based local resolution.

### Notes

- All files in `unbound.conf.d/` are automatically read by Unbound via a **wildcard include** directive in `unbound.conf`.
- Modify `20-private-domains.conf` as needed to allow other trusted services that require resolving private IPs.

# Pi-hole v6 + Unbound in Docker

## Summary

This is a **baseline setup of Pi-hole and Unbound** using Docker. It assumes that you already have a gateway/router
with a **separate DHCP and NTP server**. If you want Pi-hole to handle DHCP, additional configuration is needed.

This setup follows the official **[Pi-hole Unbound guide](https://docs.pi-hole.net/guides/dns/unbound/)** but adapts
it for **Pihole v6 and Docker Compose**.

In this setup, **Unbound does not have its own network interface**; instead, it runs using **Pi-hole’s network stack**
(`network_mode: service:pihole`). This means:

- **Unbound is not exposed to the host network** but can still resolve recursive DNS queries.
- **Pi-hole forwards all upstream DNS queries** to `127.0.0.1#5335`, where Unbound handles recursive lookups.
- **No additional networking configurations are needed** for Unbound.

---

## Prerequisites

Before you begin, ensure you are running:

- A **Debian or Debian-based Linux distribution** (Ubuntu, Raspberry Pi OS, etc.)
- [**Docker** installed](https://docs.docker.com/engine/install/)

---

## Step 1: Create the Directory Structure for Bind Mounts

Before downloading the repository, set up the necessary directories for your **bind mounts**.

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

### **What These Commands Do**

- `mkdir -p ~/docker/pihole-unbound`: Creates a working directory in your home folder.
- `sudo mkdir -p /srv/docker/...`: Creates **bind mounts** for Pi-hole and Unbound.
- `sudo chown -R $USER:$USER /srv/docker`: Ensures **your user owns the folders**.
- `chmod -R 755 /srv/docker`: Sets **read/write permissions** for better access.
- `touch unbound.log`: Prepares the **log file for Unbound**.

---

## Step 2: Download the Repository

You can download the latest version of this repository using **`wget`** or **`curl`**:

**Option 1: Using `wget`**

```bash
wget https://github.com/kaczmar2/pihole-unbound/archive/refs/heads/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
```

**Option 2: Using `curl`**

```bash
curl -L -o main.tar.gz https://github.com/kaczmar2/pihole-unbound/archive/refs/heads/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
```

The `--strip-components=1` flag ensures the contents are extracted directly into `~/docker/pihole-unbound` instead of
creating an extra subdirectory.

**Note**: This setup now uses the official `alpinelinux/unbound` Docker image, which provides better security, regular
updates, and cross-platform compatibility (including Raspberry Pi).

Optional: Remove the archive after extraction:

```sh
rm main.tar.gz
```

---

## Step 3: Start the Pi-hole + Unbound Containers

Now, deploy the Pi-hole and Unbound services using:

```bash
docker compose up -d
```

---

## Step 4: Verify Unbound is Working

To confirm Unbound is resolving queries correctly, run the following commands **in the pihole container**:

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

The first command should give a status report of SERVFAIL and no IP address. The second should give NOERROR plus an IP address.

---

## Step 5: Set the Pi-hole Admin Password

To set the pihole web admin password, run the following commands **in the pihole container**, if you're not already
there from the previous step (`docker exec -it pihole /bin/bash`):

```bash
pihole setpassword 'mypassword'
```

Get the hashed password from `pihole.toml`:

```bash
cat /etc/pihole/pihole.toml | grep -w pwhash
```

`exit` the container and copy the hashed password into your `.env` file on the host.

Make sure to enclose the value in single quotes (`''`).

```bash
WEB_PWHASH='$BALLOON-SHA256$v=1$s=1024,t=32$pZCbBIUH/Ew2n144eLn3vw==$vgej+obQip4DvSmNlywD0LUHlsHcqgLdbQLvDscZs78='
```

Uncomment the `FTLCONF_webserver_api_pwhash` environment variable in `docker-compose.yml`:

```bash
FTLCONF_webserver_api_pwhash: ${WEB_PWHASH}
```

Restart the containers:

```bash
docker compose down && docker compose up -d
```

## Step 6: Access the Pi-hole Web Interface

Once running, open your web browser and go to:

```bash
http://<your-server-ip>/admin/
```

Login using the password you set.

---

## Common Issues & Troubleshooting

### Fix `so-rcvbuf` warning in Unbound (Optional)

The configuration in `pi-hole.conf` sets the **socket receive buffer size** for incoming DNS queries to a
higher-than-default value in order to handle high query rates.

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

## Step 8: Secure with SSL (Optional)

For enhanced security, see my other guides on **configuring SSL encryption** for the Pi-hole web interface.

- [Pi-hole v6 + Docker: Automating Let's Encrypt SSL Renewal with Cloudflare DNS](https://gist.github.com/kaczmar2/027fd6f64f4e4e7ebbb0c75cb3409787#file-pihole-v6-docker-le-cf-md)

---

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

# Pi-hole v6 + Unbound in Docker

## 🔹 Summary
This is a **baseline setup of Pi-hole and Unbound** using Docker. It assumes that you already have a consumer router with a **separate DHCP and NTP server** (such as **Netgear, TP-Link, UniFi, etc.**). If you want Pi-hole to handle DHCP, additional configuration is needed.

This setup follows the official **[Pi-hole Unbound guide](https://docs.pi-hole.net/guides/dns/unbound/)** but adapts it for **Pihole v6 and Docker Compose**.

---

## Prerequisites
Before you begin, ensure you are running:
- A **Debian or Debian-based Linux distribution** (Ubuntu, Raspberry Pi OS, etc.)
- [**Docker** installed](https://docs.docker.com/engine/install/)

## Step 1: Create the Directory Structure for Bind Mounts
Before downloading the repository, set up the necessary directories for your **bind mounts**.

Run the following commands:

```sh
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
```sh
wget https://github.com/kaczmar2/pihole-unbound/archive/refs/heads/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
```

**Option 2: Using `curl`**
```sh
curl -L -o main.tar.gz https://github.com/kaczmar2/pihole-unbound/archive/refs/heads/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
```

The `--strip-components=1` flag ensures the contents are extracted directly into `~/docker/pihole-unbound` instead of creating an extra subdirectory.

**Optional: Remove the archive after extraction**
```sh
rm main.tar.gz
```

---

## Step 3: Start the Pi-hole + Unbound Containers
Now, deploy the Pi-hole and Unbound services using:

```sh
docker compose up -d
```

---

## Step 4: Verify Unbound is Working

To confirm Unbound is resolving queries correctly, run the following commands **on the host**:

Test that Unbound is operational:

```sh
dig pi-hole.net @172.31.99.3 -p 5335
```

The first query may be quite slow, but subsequent queries should be fairly quick.

**Test validation**

```sh
dig fail01.dnssec.works @172.31.99.3 -p 5335
dig dnssec.works @172.31.99.3 -p 5335
```

The first command should give a status report of SERVFAIL and no IP address. The second should give NOERROR plus an IP address.

---

## Step 5: Set the Pi-hole Admin Password

```
docker exec -it pihole pihole setpassword 'mypassword'
```

Get the hashed password from `pihole.toml`:
```
cat /srv/docker/pihole-unbound/pihole/etc-pihole/pihole.toml | grep "pwhash"
```

Copy the hashed password into `.env`:
```
WEB_PWHASH='$BALLOON-SHA256$v=1$s=1024,t=32$pZCbBIUH/Ew2n144eLn3vw==$vgej+obQip4DvSmNlywD0LUHlsHcqgLdbQLvDscZs78='
```

Uncomment the `FTLCONF_webserver_api_pwhash` enviornment variable in docker-compose.yml:
```
FTLCONF_webserver_api_pwhash: ${WEB_PWHASH}
```

Restart the containers:
```
docker compose down
docker compose up -d
```

## Step 6: Access the Pi-hole Web Interface
Once running, open your web browser and go to:

```
http://<your-server-ip>/admin/
```

Login using the password you set.

---

## Step 7: Secure with SSL (Optional)
For enhanced security, see my other guides on **configuring SSL encryption** for the Pi-hole web interface.
- [Pi-hole v6 + Docker: Automating Let's Encrypt SSL Renewal with Cloudflare DNS](https://gist.github.com/kaczmar2/027fd6f64f4e4e7ebbb0c75cb3409787#file-pihole-v6-docker-le-cf-md)
---

## ❤️ Contributing
Feel free to **fork** the repository, submit **pull requests**, or open **issues** if you have suggestions.

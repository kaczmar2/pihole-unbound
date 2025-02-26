# Pi-hole v6 + Unbound in Docker

This repository provides a **Docker Compose** setup for running **Pi-hole v6** with **Unbound** as a recursive DNS resolver.

---

## Prerequisites
Before you begin, ensure you are running:
- A **Debian or Debian-based Linux distribution** (Ubuntu, Raspberry Pi OS, etc.)
- **Docker** and **Docker Compose** installed  

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

---

## Step 3: Start the Pi-hole + Unbound Containers
Now, deploy the Pi-hole and Unbound services using:

```sh
docker compose up -d
```

To check running containers:

```sh
docker ps
```

---

## Step 4: Verify Unbound is Working
To confirm Unbound is resolving queries correctly, run:

```sh
dig pi-hole.net @172.31.99.3 -p 5335
dig fail01.dnssec.works @172.31.99.3 -p 5335
dig dnssec.works @172.31.99.3 -p 5335
```

If Unbound is working correctly, you should see **valid DNS responses**.

---

## Step 5: Set the Pi-hole Admin Password
You can set the password via the web UI or by running the following command:

```sh
docker exec -it pihole pihole -a -p
```

You will be prompted to enter a new password.

Alternatively, to **generate a password hash** and copy it into `.env`:

```sh
docker exec -it pihole /bin/bash
pihole -a -p
```

If you need to reset the password in the future, you can run:

```sh
docker exec -it pihole pihole -a -p
```

---

## Step 6: Access the Pi-hole Web Interface
Once running, open your web browser and go to:

```
http://<your-server-ip>/admin/
```

Login using the password you set.

---

## Step 7: Secure with SSL (Optional)
For enhanced security, see my other guides on **configuring SSL encryption** for the Pi-hole web interface.

---

## ❤️ Contributing
Feel free to **fork** the repository, submit **pull requests**, or open **issues** if you have suggestions or improvements!

---

## 📢 Share & Discuss
If you find this useful, share it with the community on **Reddit, forums, or GitHub discussions!** 🚀
```

#!/bin/bash

# JellyfinXArrStack_Fail2Ban - Debian Media Server Setup
# User: Boss
# -Made by TerminalX Group-

set -e

echo "Starting JellyfinXArrStack setup for Debian..."

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure required tools
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

####################################
# Install Docker (Debian)
####################################
if ! command_exists docker; then
    echo "Installing Docker..."

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker
fi

####################################
# Docker Compose (legacy fallback)
####################################
if ! command_exists docker-compose; then
    echo "Installing docker-compose (legacy)..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

####################################
# Timezone
####################################
read -p "Enter your timezone (e.g., Europe/Brussels): " TIMEZONE
sudo timedatectl set-timezone "$TIMEZONE"

####################################
# Auto-login on tty1
####################################
USER_NAME=$(whoami)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

####################################
# Disk selection
####################################
echo "Available drives:"
lsblk -f
read -p "Select disk to use (e.g., /dev/sdb): " DISK

if [ ! -b "$DISK" ]; then
    echo "Disk not found"
    exit 1
fi

read -p "Is the disk formatted as EXT4? (y/n): " FORMATTED
if [[ "$FORMATTED" == "n" ]]; then
    sudo mkfs.ext4 "$DISK"
fi

MOUNT="/mnt/media-server"
sudo mkdir -p "$MOUNT"
sudo mount "$DISK" "$MOUNT"

UUID=$(sudo blkid -s UUID -o value "$DISK")
grep -q "$UUID" /etc/fstab || \
echo "UUID=$UUID $MOUNT ext4 defaults 0 2" | sudo tee -a /etc/fstab

####################################
# Media folders
####################################
sudo mkdir -p \
    "$MOUNT/movies" \
    "$MOUNT/series" \
    "$MOUNT/config"

sudo chown -R $USER_NAME:$USER_NAME "$MOUNT"

####################################
# DNS (optional but forced here)
####################################
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

####################################
# Firewall
####################################
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 8096/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 8989/tcp
sudo ufw allow 7878/tcp
sudo ufw allow 9696/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 6881/tcp
sudo ufw allow 6881/udp
sudo ufw allow 6767/tcp
sudo ufw --force enable

####################################
# Automatic Updates
####################################
sudo apt install -y unattended-upgrades
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades

####################################
# Fail2Ban
####################################
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

####################################
# Docker Compose Stack
####################################
COMPOSE="$MOUNT/config/docker-compose.yml"

cat > "$COMPOSE" <<EOL
version: "3.8"

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    ports:
      - "8096:8096"
    volumes:
      - $MOUNT/movies:/media/movies
      - $MOUNT/series:/media/series
      - $MOUNT/config/jellyfin:/config
    environment:
      - TZ=$TIMEZONE
    restart: unless-stopped

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $MOUNT/config/portainer:/data
    restart: unless-stopped

  sonarr:
    image: linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
    volumes:
      - $MOUNT/series:/tv
      - $MOUNT/movies:/downloads
      - $MOUNT/config/sonarr:/config
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
    volumes:
      - $MOUNT/movies:/movies
      - $MOUNT/movies:/downloads
      - $MOUNT/config/radarr:/config
    ports:
      - "7878:7878"
    restart: unless-stopped

  prowlarr:
    image: linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
    volumes:
      - $MOUNT/config/prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped

  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
      - WEBUI_PORT=8080
    volumes:
      - $MOUNT/config/qbittorrent:/config
      - $MOUNT/movies:/downloads
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped

  bazarr:
    image: linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$TIMEZONE
    volumes:
      - $MOUNT/config/bazarr:/config
      - $MOUNT/movies:/movies
      - $MOUNT/series:/series
    ports:
      - "6767:6767"
    restart: unless-stopped
EOL

####################################
# Start stack
####################################
cd "$MOUNT/config"

if command_exists docker-compose; then
    docker-compose pull
    docker-compose up -d
else
    docker compose pull
    docker compose up -d
fi

echo "======================================"
echo " JellyfinXArrStack_Fail2Ban (Debian)"
echo "======================================"
echo "✔ Disk mounted on boot"
echo "✔ Auto-login enabled"
echo "✔ Firewall active"
echo "✔ Fail2Ban running"
echo "✔ Automatic updates enabled"
echo "✔ Containers running"
echo ""
echo "Manage stack:"
echo "cd $MOUNT/config && docker compose ps"

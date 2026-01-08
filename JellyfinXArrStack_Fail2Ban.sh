#!/bin/bash

# JellyfinXArrStack_Fail2Ban - Media Server Setup
# User: Boss
# -Made by TerminalX Group-

set -e

echo "Starting Jellyfix setup..." 

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Docker if missing
if ! command_exists docker; then
    echo "Installing Docker..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Install Docker Compose if missing
if ! command_exists docker-compose; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Timezone
read -p "Enter your timezone (e.g., Europe/Brussels): " TIMEZONE
sudo timedatectl set-timezone "$TIMEZONE"

# Enable auto-login
USER=$(whoami)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo bash -c "cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF"

# Select disk
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

# Add to fstab
UUID=$(sudo blkid -s UUID -o value "$DISK")
sudo bash -c "echo 'UUID=$UUID $MOUNT ext4 defaults 0 2' >> /etc/fstab"

# Folders
sudo mkdir -p "$MOUNT/movies" "$MOUNT/series" "$MOUNT/config"
sudo chown -R $USER:$USER "$MOUNT"

# DNS
sudo bash -c 'cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF'

# Firewall
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

# Automatic updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades

# Install Fail2Ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Docker Compose
COMPOSE="$MOUNT/config/docker-compose.yml"
cat > "$COMPOSE" <<EOL
version: '3.8'

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
    restart: unless-stopped
    environment:
      - TZ=$TIMEZONE

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
      - $MOUNT/config/sonarr:/config
      - $MOUNT/movies:/downloads
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
      - $MOUNT/config/radarr:/config
      - $MOUNT/movies:/downloads
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

networks:
  default:
    driver: bridge
EOL

cd "$MOUNT/config"
docker-compose pull
docker-compose up -d

echo "JellyfinXArrStack_Fail2Ban setup finished."
echo "Disk mounts on boot. Auto-login enabled. Firewall active. Fail2Ban running. Updates automatic."
echo "Containers running. Manage with: cd $MOUNT/config && docker-compose ps"

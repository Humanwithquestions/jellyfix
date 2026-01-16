#!/bin/bash

# JellyfinXArrStack_Fail2Ban - Debian Desktop Media Server Setup (Production + Backup)
# User: Boss
# -Made by TerminalX Group-

set -e

echo "Starting JellyfinXArrStack setup for Debian Desktop (Production + Backup)..."

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

####################################
# Required packages
####################################
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release ufw unattended-upgrades fail2ban parted tar

####################################
# Docker installation
####################################
if ! command_exists docker; then
    echo "Installing Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
fi

####################################
# Legacy Docker Compose fallback
####################################
if ! command_exists docker-compose; then
    echo "Installing legacy docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

####################################
# Timezone input safely
####################################
while true; do
    read -p "Enter your timezone (e.g., Europe/Brussels): " TIMEZONE
    if timedatectl list-timezones | grep -qx "$TIMEZONE"; then
        sudo timedatectl set-timezone "$TIMEZONE"
        echo "Timezone set to $TIMEZONE"
        break
    else
        echo "Invalid timezone, please try again."
    fi
done

####################################
# User info for containers
####################################
USER_NAME=$(whoami)
PUID=$(id -u "$USER_NAME")
PGID=$(id -g "$USER_NAME")
echo "Using PUID=$PUID and PGID=$PGID for containers."

####################################
# Auto-login on tty1
####################################
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

####################################
# Prevent system idle / sleep
####################################
sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=suspend/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#IdleAction=suspend/IdleAction=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind
sudo setterm -blank 0 -powerdown 0 -powersave off

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.screensaver lock-enabled false || true
    gsettings set org.gnome.desktop.session idle-delay 0 || true
fi

####################################
# Disk selection and automatic partitioning
####################################
echo "Available drives:"
lsblk -d -o NAME,SIZE,MODEL
read -p "Select disk for media server (e.g., sdb): " DISKNAME
DISK="/dev/$DISKNAME"

if [ ! -b "$DISK" ]; then
    echo "Disk not found!"
    exit 1
fi

echo "⚠ WARNING: All data on $DISK will be erased!"
read -p "Type 'YES' to continue: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

sudo wipefs -a "$DISK"
sudo parted -s "$DISK" mklabel gpt
sudo parted -s -a optimal "$DISK" mkpart primary ext4 0% 100%
PARTITION="${DISK}1"
sudo mkfs.ext4 "$PARTITION"

MOUNT="/mnt/media-server"
sudo mkdir -p "$MOUNT"
sudo mount "$PARTITION" "$MOUNT"

UUID=$(sudo blkid -s UUID -o value "$PARTITION")
grep -q "$UUID" /etc/fstab || \
echo "UUID=$UUID $MOUNT ext4 defaults 0 2" | sudo tee -a /etc/fstab
echo "✅ Disk $DISK partitioned and mounted at $MOUNT"

####################################
# Create media folders
####################################
sudo mkdir -p "$MOUNT/movies" "$MOUNT/series" "$MOUNT/config"
sudo chown -R $USER_NAME:$USER_NAME "$MOUNT"

####################################
# DNS
####################################
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

####################################
# Firewall
####################################
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
# Automatic updates & Fail2Ban
####################################
sudo systemctl enable unattended-upgrades fail2ban
sudo systemctl start unattended-upgrades fail2ban

####################################
# Docker network
####################################
NETWORK="media"
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    docker network create "$NETWORK"
fi

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
    networks:
      - $NETWORK
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
    networks:
      - $NETWORK
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $MOUNT/config/portainer:/data
    restart: unless-stopped

  sonarr:
    image: linuxserver/sonarr:latest
    container_name: sonarr
    networks:
      - $NETWORK
    environment:
      - PUID=$PUID
      - PGID=$PGID
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
    networks:
      - $NETWORK
    environment:
      - PUID=$PUID
      - PGID=$PGID
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
    networks:
      - $NETWORK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIMEZONE
    volumes:
      - $MOUNT/config/prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped

  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    networks:
      - $NETWORK
    environment:
      - PUID=$PUID
      - PGID=$PGID
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
    networks:
      - $NETWORK
    environment:
      - PUID=$PUID
      - PGID=$PGID
      - TZ=$TIMEZONE
    volumes:
      - $MOUNT/config/bazarr:/config
      - $MOUNT/movies:/movies
      - $MOUNT/series:/series
    ports:
      - "6767:6767"
    restart: unless-stopped

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    networks:
      - $NETWORK
    environment:
      - TZ=$TIMEZONE
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=300
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

networks:
  $NETWORK:
    external: true
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

####################################
# Backup container configs
####################################
BACKUP_DIR="$MOUNT/backup"
mkdir -p "$BACKUP_DIR"

BACKUP_SCRIPT="$MOUNT/config/backup-configs.sh"
cat > "$BACKUP_SCRIPT" <<'EOL'
#!/bin/bash
# Backup container configs
BACKUP_DIR="/mnt/media-server/backup"
CONFIG_DIR="/mnt/media-server/config"
DATE=$(date +%F_%H-%M-%S)
MAX_BACKUPS=7

tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C "$CONFIG_DIR" .
cd "$BACKUP_DIR"
ls -1tr | head -n -$MAX_BACKUPS | xargs -d '\n' rm -f 2>/dev/null || true
EOL

chmod +x "$BACKUP_SCRIPT"

sudo tee /etc/systemd/system/media-backup.service > /dev/null <<EOF
[Unit]
Description=Backup media server configs

[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT
EOF

sudo tee /etc/systemd/system/media-backup.timer > /dev/null <<EOF
[Unit]
Description=Daily backup of media server configs

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now media-backup.timer

echo "✅ Daily automatic backups enabled in $BACKUP_DIR (last 7 kept)"

echo "======================================"
echo " JellyfinXArrStack_Fail2Ban (Debian Desktop, Production + Backup)"
echo "======================================"
echo "✔ Disk partitioned and mounted"
echo "✔ Auto-login enabled"
echo "✔ System sleep prevented / screensaver disabled"
echo "✔ Firewall active"
echo "✔ Fail2Ban running"
echo "✔ Automatic updates enabled"
echo "✔ Docker network created: $NETWORK"
echo "✔ Containers running (with Watchtower auto-updates)"
echo "✔ Daily automatic backups enabled"
echo ""
echo "Manage stack:"
echo "cd $MOUNT/config && docker compose ps"

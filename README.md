#🍿 Jellyfix – Automated Jellyfin Media Server Stack

Jellyfix is an all-in-one Ubuntu media server installer that automatically sets up:

Jellyfin

Sonarr

Radarr

Prowlarr

qBittorrent

Bazarr

Portainer

Docker & Docker Compose

Firewall (UFW)

Fail2Ban

Automatic security updates

Disk formatting & mounting

All with one script.

#⚠️ Important Warning

This script can format disks.

Make sure you select the correct disk, or data loss WILL occur.

Jellyfix is intended for fresh servers or dedicated media disks.

🖥️ Supported Systems

✅ Ubuntu 20.04 LTS

✅ Ubuntu 22.04 LTS

✅ Ubuntu 24.04 LTS

❌ Not recommended for desktops

❌ Not recommended for systems with existing important data

#📦 What Jellyfix Installs
Component	Purpose
Docker	Container runtime
Docker Compose	Container orchestration
Jellyfin	Media server
Sonarr	TV automation
Radarr	Movie automation
Prowlarr	Indexer manager
qBittorrent	Torrent client
Bazarr	Subtitle management
Portainer	Docker UI
UFW	Firewall
Fail2Ban	SSH brute-force protection
Unattended Upgrades	Automatic security updates
🚀 Installation
1️⃣ Prepare Your Server

Update your system and install Git:

sudo apt update && sudo apt upgrade -y
sudo apt install -y git

2️⃣ Clone the Repository
git clone https://github.com/Humanwithquestions/jellyfix.git
cd jellyfix

3️⃣ Make the Script Executable
chmod +x jellyfix.sh


(Replace jellyfix.sh with the actual script name if different.)

4️⃣ Run the Installer
sudo ./jellyfix.sh


⚠️ Must be run with sudo (disk mounting, firewall, Docker install).

🧭 Installation Prompts Explained

During installation, Jellyfix will ask you for:

🕒 Timezone

Example:

Europe/Brussels
America/New_York

💽 Disk Selection

You will see a list of available disks:

/dev/sdb
/dev/nvme0n1


Choose the disk dedicated to media storage.

🧹 Disk Formatting

You will be asked if the disk is already EXT4:

y → Keep data

n → Format disk (DESTROYS DATA)

📂 Default Directory Structure

Jellyfix mounts your disk at:

/mnt/media-server


Folders created automatically:

/mnt/media-server/
├── movies
├── series
└── config
    ├── jellyfin
    ├── sonarr
    ├── radarr
    ├── prowlarr
    ├── qbittorrent
    ├── bazarr
    └── portainer

#🌐 Access Your Services

Replace <SERVER-IP> with your server’s IP address.

Service	URL
Jellyfin	http://<SERVER-IP>:8096
Portainer	http://<SERVER-IP>:9000
Sonarr	http://<SERVER-IP>:8989
Radarr	http://<SERVER-IP>:7878
Prowlarr	http://<SERVER-IP>:9696
qBittorrent	http://<SERVER-IP>:8080
Bazarr	http://<SERVER-IP>:6767
🔥 Firewall Rules (UFW)

The following ports are opened automatically:

SSH (22)

Jellyfin (8096)

Portainer (9000)

Sonarr (8989)

Radarr (7878)

Prowlarr (9696)

qBittorrent (8080, 6881 TCP/UDP)

Bazarr (6767)

Check status:

sudo ufw status

🛡️ Security Features

✅ Fail2Ban enabled (protects SSH)

✅ Firewall enabled

✅ Automatic security updates

✅ Containers restart automatically

🐳 Managing Containers

Go to the config directory:

cd /mnt/media-server/config


Check status:

docker compose ps


Restart stack:

docker compose restart


Stop stack:

docker compose down


Update containers:

docker compose pull
docker compose up -d

❓ Troubleshooting
Docker permission denied

Log out and back in, or reboot:

reboot

Disk not mounting on reboot

Check:

cat /etc/fstab

Containers not starting

View logs:

docker compose logs -f

🧠 Recommended Next Steps

Configure Sonarr/Radarr download paths

Set qBittorrent categories

Connect Prowlarr indexers

Secure services with a reverse proxy (Traefik / Caddy)

🧩 Planned Improvements

HTTPS support (Traefik)

VPN support (Gluetun)

Non-interactive install flags

Debian support

GPU transcoding options

📜 Disclaimer

This project is provided as-is.
The author is not responsible for data loss or misconfiguration.

⭐ Support the Project

If Jellyfix helped you:

⭐ Star the repo

🐛 Open issues

💡 Submit pull requests

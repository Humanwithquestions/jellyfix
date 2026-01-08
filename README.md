# jellyfix

Automated setup scripts for a home media server on Ubuntu. Installs Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Bazarr, and Portainer using Docker and Docker Compose.

Two versions are included:

Bare-minimum version – lightweight setup for small drives, only essential services.

Fail2Ban version – includes Fail2Ban to protect SSH from repeated login attempts.

# Features

-Automatic disk detection, formatting, and mounting.

-Creates folder structure:

-/movies – for movie files

-/series – for TV shows

-/config – for container configurations

-Installs Docker & Docker Compose if not present.

-Sets timezone and enables auto-login.

-Configures DNS.

-Enables UFW firewall and opens required ports.

-Enables automatic system updates.

-Fully configured docker-compose.yml for all services.

-Optional Fail2Ban protection (only in Fail2Ban version).

-Pulls and starts all Docker containers automatically.

-Requirements

-Fresh Ubuntu Server installation.

-One additional hard disk for media and configuration.

-Internet connection.

# Installation
1. Bare-minimum version

Run the following commands:

curl -fsSL https://raw.githubusercontent.com/Humanwithquestions/terminalx/main/JellyfinXArrStack.sh -o JellyfinXArrStack.sh
chmod +x JellyfinXArrStack.sh
./JellyfinXArrStack.sh


Follow the prompts:

Select disk and confirm formatting if necessary.

Set your timezone.
https://www.timeanddate.com/time/map/

The script will automatically install Docker, set up folders, configure firewall, and start all containers.

2. Fail2Ban version

Run the Fail2Ban script for added SSH protection:

curl -fsSL https://raw.githubusercontent.com/Humanwithquestions/terminalx/main/JellyfinXArrStack_Fail2Ban.sh -o JellyfinXArrStack_Fail2Ban.sh
chmod +x JellyfinXArrStack_Fail2Ban.sh
./JellyfinXArrStack_Fail2Ban.sh


Same prompts as above, with Fail2Ban installed and running to block repeated login attempts.

Accessing Services
Service	    Port	    Notes
Jellyfin	8096	Media server UI
Portainer	9000	Docker management UI
Sonarr	    8989	TV show automation
Radarr	    7878	Movie automation
Prowlarr	9696	Indexer manager
qBittorrent	8080	Torrent client
Bazarr	    6767	Subtitle management

Access services via browser: http://YOUR_SERVER_IP:PORT

Security Notes

Bare-minimum version relies on UFW firewall only.

Fail2Ban version automatically blocks IPs after repeated failed SSH login attempts.

For additional security:

Use SSH key authentication and disable passwords.

Keep Docker and container images updated.

Notes

Scripts are optimized for small drives; no backup system included.

Docker volumes and configurations are stored in /mnt/media-server/config.

Only required ports are opened by UFW; all other connections are blocked.

License

MIT License – free to use and modify.
-Made by TerminalX Group-

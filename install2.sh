#!/bin/bash
set -e

# === Farben definieren ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Benutzer- und Sudo-Erkennung ===
if [ "$EUID" -eq 0 ]; then
  USERNAME="${SUDO_USER:-root}"
  SUDO=""
else
  echo -e "${RED}❌ Dieses Skript muss mit Root-Rechten gestartet werden (z. B. per sudo).${NC}"
  exit 1
fi

# === Header ===
clear
echo -e "${BLUE}###############################################################"
echo "#                                                             #"
echo "#  LiveStreamDVR Full Installer (MrBrax-Version + wahke-Style)#"
echo "#                                                             #"
echo "#  Erstellt mit Herz von wahke.lu                             #"
echo "#  © 2025 wahke.lu – Alle Rechte vorbehalten                  #"
echo "#                                                             #"
echo "#  Unterstützte Systeme:                                      #"
echo "#    - Ubuntu, Debian, Fedora, CentOS, Rocky, AlmaLinux       #"
echo "#    - Arch Linux, Manjaro                                    #"
echo "#                                                             #"
echo "#  Komponenten:                                               #"
echo "#    - LiveStreamDVR (mit Submodules + Build)                 #"
echo "#    - NGINX Reverse Proxy + SSL mit Let's Encrypt            #"
echo "#    - systemd-Service                                        #"
echo "#                                                             #"
echo "#  Installationspfad: /opt/livestreamdvr                      #"
echo "#  Dienstname: livestreamdvr                                  #"
echo "#                                                             #"
echo "###############################################################${NC}"
echo ""
echo -e "${YELLOW}Version 1.0.1${NC}"
echo ""

# === Eingaben ===
read -p "📝 Bitte gib deine Domain ein (z.B. stream.example.com): " DOMAIN
read -p "📧 Bitte gib deine E-Mail-Adresse für Let's Encrypt ein: " EMAIL

# === Distro-Erkennung + Pakete ===
echo -e "${BLUE}>>> Erkenne Distribution und installiere Abhängigkeiten...${NC}"

install_packages_debian() {
  apt update
  apt install -y sudo git python3 python3-venv python3-pip nginx certbot python3-certbot-nginx ffmpeg curl nodejs npm yarn
}

install_packages_fedora() {
  dnf install -y sudo git python3 python3-venv python3-pip nginx certbot python3-certbot-nginx ffmpeg curl nodejs npm yarn
}

install_packages_arch() {
  pacman -Sy --noconfirm sudo git python python-virtualenv python-pip nginx certbot python-certbot-nginx ffmpeg curl nodejs npm yarn
}

if [ -f /etc/debian_version ]; then
  install_packages_debian
elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
  install_packages_fedora
elif [ -f /etc/arch-release ]; then
  install_packages_arch
else 
  echo -e "${RED}❌ Diese Distribution wird derzeit nicht automatisch unterstützt.${NC}"
  exit 1 
fi

# === Zielverzeichnis ===
echo -e "${BLUE}>>> Erstelle Zielverzeichnis...${NC}"
mkdir -p /opt/livestreamdvr
chown "$USERNAME":"$USERNAME" /opt/livestreamdvr
cd /opt/livestreamdvr

# === Repository klonen ===
echo -e "${BLUE}>>> Klone LiveStreamDVR inkl. Submodules...${NC}"
sudo -u "$USERNAME" git clone --recurse-submodules https://github.com/MrBrax/LiveStreamDVR.git .
sudo -u "$USERNAME" git submodule update --init --recursive

# === Python venv ===
echo -e "${BLUE}>>> Erstelle Python venv...${NC}"
sudo -u "$USERNAME" python3 -m venv venv
source venv/bin/activate
sudo -u "$USERNAME" venv/bin/pip install --break-system-packages -r requirements.txt

# === Yarn Build ===
echo -e "${BLUE}>>> Baue Komponenten mit Yarn: twitch-vod-chat${NC}"
cd twitch-vod-chat
sudo -u "$USERNAME" yarn install
sudo -u "$USERNAME" yarn run buildlib
cd ..

echo -e "${BLUE}>>> Baue Komponenten mit Yarn: client-vue${NC}"
cd client-vue
sudo -u "$USERNAME" yarn install
sudo -u "$USERNAME" yarn run build
cd ..

echo -e "${BLUE}>>> Baue Komponenten mit Yarn: server${NC}"
cd server
sudo -u "$USERNAME" yarn install
sudo -u "$USERNAME" yarn run build
cd ..

echo -e "${BLUE}>>> Baue Komponenten mit Yarn: twitch-chat-dumper${NC}"
cd twitch-chat-dumper
sudo -u "$USERNAME" yarn install
sudo -u "$USERNAME" yarn run build
cd ..

# === NGINX konfigurieren ===
echo -e "${BLUE}>>> Konfiguriere NGINX...${NC}"

cat > /etc/nginx/sites-available/livestreamdvr <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/livestreamdvr /etc/nginx/sites-enabled/livestreamdvr
nginx -t && systemctl reload nginx

# === Let's Encrypt ===
echo -e "${BLUE}>>> Beantrage SSL-Zertifikat...${NC}"
certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

# === systemd-Dienst ===
echo -e "${BLUE}>>> Erstelle livestreamdvr systemd-Dienst...${NC}"

cat > /etc/systemd/system/livestreamdvr.service <<EOF
[Unit]
Description=LiveStreamDVR (MrBrax-Version)
After=network.target

[Service]
WorkingDirectory=/opt/livestreamdvr/server
ExecStart=$(which yarn) run start
Restart=always
User=$USERNAME
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable livestreamdvr
systemctl start livestreamdvr

# === Abschluss ===
echo ""
echo -e "${GREEN}✅ Installation abgeschlossen!${NC}"
echo -e "${YELLOW}🔗 LiveStreamDVR ist erreichbar unter: https://$DOMAIN${NC}"
echo -e "${YELLOW}📦 Dienststatus prüfen mit: ${NC} ${BLUE}sudo systemctl status livestreamdvr${NC}"

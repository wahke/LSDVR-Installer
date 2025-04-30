#!/bin/bash
set -e

# === Root-Prüfung ===
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führe dieses Skript mit Root-Rechten aus (z. B. per sudo)."
  exit 1
fi

# === Header ===
clear
echo "###############################################################"
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
echo "###############################################################"
echo ""

# === Eingaben ===
read -p "Bitte gib deine Domain ein (z.B. stream.example.com): " DOMAIN
read -p "Bitte gib deine E-Mail-Adresse für Let's Encrypt ein: " EMAIL

# === Distro-Erkennung + Pakete installieren ===
echo ">>> Erkenne Distribution und installiere Abhängigkeiten..."

install_packages_debian() {
  apt update
  apt install -y git python3 python3-venv python3-pip nginx certbot python3-certbot-nginx ffmpeg curl nodejs npm yarn
}

install_packages_fedora() {
  dnf install -y git python3 python3-venv python3-pip nginx certbot python3-certbot-nginx ffmpeg curl nodejs npm yarn
}

install_packages_arch() {
  pacman -Sy --noconfirm git python python-virtualenv python-pip nginx certbot python-certbot-nginx ffmpeg curl nodejs npm yarn
}

if [ -f /etc/debian_version ]; then
  install_packages_debian
elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
  install_packages_fedora
elif [ -f /etc/arch-release ]; then
  install_packages_arch
else
  echo "❌ Diese Distribution wird derzeit nicht automatisch unterstützt."
  exit 1
fi

# === Zielverzeichnis vorbereiten ===
echo ">>> Erstelle Zielverzeichnis..."
mkdir -p /opt/livestreamdvr
chown "$SUDO_USER":"$SUDO_USER" /opt/livestreamdvr
cd /opt/livestreamdvr

# === Repository klonen ===
echo ">>> Klone LiveStreamDVR inkl. Submodules..."
sudo -u "$SUDO_USER" git clone --recurse-submodules https://github.com/MrBrax/LiveStreamDVR.git .
sudo -u "$SUDO_USER" git submodule update --init --recursive

# === Python venv einrichten ===
echo ">>> Erstelle Python-Umgebung..."
sudo -u "$SUDO_USER" python3 -m venv venv
source venv/bin/activate
sudo -u "$SUDO_USER" pip install -r requirements.txt

# === Yarn Build-Schritte ===
echo ">>> Baue Komponenten..."

cd twitch-vod-chat
sudo -u "$SUDO_USER" yarn install
sudo -u "$SUDO_USER" yarn run buildlib
cd ..

cd client-vue
sudo -u "$SUDO_USER" yarn install
sudo -u "$SUDO_USER" yarn run build
cd ..

cd server
sudo -u "$SUDO_USER" yarn install
sudo -u "$SUDO_USER" yarn run build
cd ..

cd twitch-chat-dumper
sudo -u "$SUDO_USER" yarn install
sudo -u "$SUDO_USER" yarn run build
cd ..

# === NGINX konfigurieren ===
echo ">>> Konfiguriere NGINX..."

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

# === Zertifikat von Let's Encrypt ===
echo ">>> Beantrage SSL-Zertifikat..."
certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

# === systemd-Dienst einrichten ===
echo ">>> Richte livestreamdvr als Dienst ein..."

cat > /etc/systemd/system/livestreamdvr.service <<EOF
[Unit]
Description=LiveStreamDVR (MrBrax-Version)
After=network.target

[Service]
WorkingDirectory=/opt/livestreamdvr/server
ExecStart=$(which yarn) run start
Restart=always
User=$SUDO_USER
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
echo "✅ Installation abgeschlossen!"
echo "LiveStreamDVR ist erreichbar unter: https://$DOMAIN"
echo "Service-Status prüfen mit: sudo systemctl status livestreamdvr"

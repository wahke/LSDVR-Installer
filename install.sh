#!/bin/bash

# === Info-Banner ===
echo "###############################################################"
echo "#                                                             #"
echo "#  LiveStreamDVR Installer                                    #"
echo "#                                                             #"
echo "#  Erstellt mit Herz von wahke.lu                             #"
echo "#  © 2025 wahke.lu – Alle Rechte vorbehalten                  #"
echo "#                                                             #"
echo "#  Unterstützte Systeme:                                      #"
echo "#    - Ubuntu, Debian, Fedora, CentOS, Rocky, AlmaLinux       #"
echo "#    - Arch Linux, Manjaro                                    #"
echo "#                                                             #"
echo "#  Inklusive Komponenten:                                     #"
echo "#    - LiveStreamDVR (per Git & Python venv)                  #"
echo "#    - NGINX Reverse Proxy (automatisch konfiguriert)         #"
echo "#    - SSL mit Let's Encrypt via Certbot                      #"
echo "#                                                             #"
echo "#  Voraussetzungen:                                           #"
echo "#    - Root-Rechte                                            #"
echo "#    - Domain zeigt auf den Server                            #"
echo "#                                                             #"
echo "#  Standardpfade & Dienste:                                   #"
echo "#    - App-Verzeichnis: /opt/livestreamdvr                    #"
echo "#    - Systemd-Service: livestreamdvr                         #"
echo "#    - Zugriff: https://deine-domain.de                       #"
echo "#                                                             #"
echo "#  Projektseite:                                              #"
echo "#  https://wahke.lu/portfolio-archive/lsdvr-install-scirpt/   #"
echo "#                                                             #"
echo "###############################################################"
echo ""
sleep 4

# === Versionierung & Auto-Update ===
LOCAL_VERSION="1.0.0"
VERSION_URL="https://raw.githubusercontent.com/wahke/LSDVR-Installer/main/version.txt"
INSTALLER_URL="https://raw.githubusercontent.com/wahke/LSDVR-Installer/main/install.sh"
SCRIPT_NAME="$(realpath "$0")"

echo "Installerskript-Version: $LOCAL_VERSION"
echo "Prüfe auf Updates..."

LATEST_VERSION=$(curl -s "$VERSION_URL" | tr -d '\r')

if [ -z "$LATEST_VERSION" ]; then
    echo "Konnte Versionsinfo nicht abrufen – fahre mit lokaler Version fort."
else
    if [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
        echo "Neue Version gefunden: $LATEST_VERSION"
        echo "Aktualisiere Skript automatisch..."
        curl -s "$INSTALLER_URL" -o "$SCRIPT_NAME"
        chmod +x "$SCRIPT_NAME"
        echo "Installationsskript aktualisiert. Starte neu..."
        exec "$SCRIPT_NAME"
        exit 0
    else
        echo "Installerskript ist aktuell."
    fi
fi
echo ""

# === Distribution erkennen ===
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Konnte Distribution nicht erkennen."
    exit 1
fi

# === Eingaben vom Benutzer ===
read -p "Bitte gib deine Domain ein (z.B. stream.example.com): " DOMAIN
read -p "Bitte gib deine E-Mail-Adresse für Let's Encrypt ein: " EMAIL

APP_DIR="/opt/livestreamdvr"
PORT=8080

# === Paketinstallation vorbereiten ===
case "$DISTRO" in
    ubuntu|debian)
        PACKAGE_CMD="apt install -y"
        UPDATE_CMD="apt update && apt upgrade -y"
        CERTBOT_PKG="certbot python3-certbot-nginx"
        ;;
    fedora)
        PACKAGE_CMD="dnf install -y"
        UPDATE_CMD="dnf upgrade -y"
        CERTBOT_PKG="certbot python3-certbot-nginx"
        ;;
    centos|rocky|almalinux)
        PACKAGE_CMD="yum install -y"
        UPDATE_CMD="yum update -y"
        CERTBOT_PKG="certbot python3-certbot-nginx"
        ;;
    arch|manjaro)
        PACKAGE_CMD="pacman -Syu --noconfirm"
        UPDATE_CMD="echo 'pacman -Syu --noconfirm ausgeführt'"
        CERTBOT_PKG="certbot certbot-nginx"
        ;;
    *)
        echo "Nicht unterstützte Distribution: $DISTRO"
        exit 1
        ;;
esac

# === System aktualisieren & Pakete installieren ===
eval "$UPDATE_CMD"
eval "$PACKAGE_CMD python3 python3-pip python3-venv git nginx ffmpeg curl $CERTBOT_PKG"

# === Benutzer livestreamdvr anlegen ===
useradd -m -s /bin/bash livestreamdvr 2>/dev/null || true

# === LiveStreamDVR installieren ===
mkdir -p "$APP_DIR"
cd "$APP_DIR"
if [ ! -d ".git" ]; then
    git clone https://github.com/MrBrax/LiveStreamDVR.git .
else
    git pull
fi

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# === systemd-Service anlegen ===
cat <<EOF > /etc/systemd/system/livestreamdvr.service
[Unit]
Description=LiveStreamDVR
After=network.target

[Service]
User=livestreamdvr
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python3 main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now livestreamdvr

# === NGINX konfigurieren ===
if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    NGINX_CONF="/etc/nginx/sites-available/livestreamdvr"
else
    NGINX_CONF="/etc/nginx/conf.d/livestreamdvr.conf"
fi

cat <<EOF > "$NGINX_CONF"
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    ln -sf /etc/nginx/sites-available/livestreamdvr /etc/nginx/sites-enabled/
fi

nginx -t && systemctl reload nginx

# === SSL einrichten ===
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

# === Abschlussmeldung ===
echo ""
echo "✅ Installation abgeschlossen!"
echo "LiveStreamDVR ist erreichbar unter:"
echo "🔗 https://$DOMAIN"
echo "Service-Status prüfen mit: systemctl status livestreamdvr"

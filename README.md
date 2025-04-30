# LiveStreamDVR Installer

Ein automatisiertes Installationsskript für [LiveStreamDVR](https://github.com/MrBrax/LiveStreamDVR), erstellt mit ❤️ von [wahke.lu](https://wahke.lu).

Dieses Skript richtet automatisch eine produktionsreife Umgebung ein – inklusive NGINX-Proxy, Let's Encrypt SSL und systemd-Service.

---

## 📖 Projektbeschreibung & Anleitung

👉 [Zur Dokumentation auf wahke.lu](https://wahke.lu/portfolio-archive/lsdvr-install-scirpt/)

---

## ✨ Features

- 🧠 Distributionserkennung (Ubuntu, Debian, Fedora, CentOS, Arch, usw.)
- 🔒 Automatische Einrichtung von SSL mit Let's Encrypt (Certbot)
- 🖥️ Systemd-Service für LiveStreamDVR
- 🌐 Zugriff über Domain ohne Port (`https://deinedomain.de`)
- 🔁 Automatische Updateprüfung des Installers

---

## 📦 Unterstützte Linux-Distributionen

- ✅ Ubuntu / Debian
- ✅ Fedora / CentOS / Rocky / AlmaLinux
- ✅ Arch Linux / Manjaro

---

## 🔧 Voraussetzungen

- Eine öffentliche Domain (z. B. `stream.example.com`), die auf deinen Server zeigt
- Root-Rechte
- Internetverbindung

---

## 🚀 Installation

```bash
curl -s https://raw.githubusercontent.com/wahke/LSDVR-Installer/main/install.sh | bash
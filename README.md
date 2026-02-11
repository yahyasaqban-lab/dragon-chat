# 🐉 Dragon Chat

A complete Discord alternative built on Matrix protocol with LiveKit for voice/video.

## 🚀 Quick Install (Ubuntu 22.04+)

```bash
curl -fsSL https://raw.githubusercontent.com/yahyasaqban-lab/dragon-chat/master/install.sh | sudo bash
```

Or with your domain:
```bash
curl -fsSL https://raw.githubusercontent.com/yahyasaqban-lab/dragon-chat/master/install.sh | sudo bash -s -- --domain example.com
```

### Requirements
- Ubuntu 22.04 or newer
- Root/sudo access
- Domain with DNS access
- Ports: 80, 443, 3478, 5349, 7880-7881, 50000-60000

### DNS Setup (before install)
Point these to your server IP:
```
matrix.yourdomain.com  →  YOUR_SERVER_IP
livekit.yourdomain.com →  YOUR_SERVER_IP  
turn.yourdomain.com    →  YOUR_SERVER_IP
```

### What Gets Installed
- **Matrix Synapse** - Chat server with E2EE
- **LiveKit** - Voice/video calls
- **Coturn** - TURN server for NAT traversal
- **PostgreSQL** - Database
- **Redis** - Caching
- **Nginx** - Reverse proxy with SSL

Credentials saved to `/opt/dragon-chat/credentials.txt`

---

## Components

| Component | Description | Path |
|-----------|-------------|------|
| **Server** | Matrix + LiveKit + Coturn setup | `/server` |
| **Desktop** | Electron app (Mac/Windows/Linux) | `/desktop` |
| **Mobile** | Flutter app (iOS/Android) | `/mobile` |

## Quick Start

### 1. Deploy Server

```bash
cd server
# Edit configs/env.conf with your domain
./scripts/01-install-all.sh
./scripts/02-start-services.sh
./scripts/03-create-admin.sh
```

### 2. Build Desktop App

```bash
cd desktop
npm install
npm start        # Development
npm run build    # Production builds
```

### 3. Build Mobile App

```bash
cd mobile
flutter pub get
flutter run              # Development
flutter build apk        # Android
flutter build ios        # iOS
```

## Features

- ✅ End-to-end encrypted messaging (Matrix)
- ✅ Voice/video calls (LiveKit WebRTC)
- ✅ Screen sharing
- ✅ Group chats and channels
- ✅ File sharing
- ✅ Push notifications
- ✅ Cross-platform (Web, Desktop, Mobile)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Clients                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Desktop  │  │  Mobile  │  │  Web (Element)   │  │
│  │ Electron │  │  Flutter │  │                  │  │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘  │
└───────┼─────────────┼─────────────────┼────────────┘
        │             │                 │
        ▼             ▼                 ▼
┌─────────────────────────────────────────────────────┐
│                   Server Stack                      │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │   Synapse   │  │   LiveKit   │  │   Coturn   │  │
│  │   Matrix    │  │  Voice/Video│  │    TURN    │  │
│  └─────────────┘  └─────────────┘  └────────────┘  │
│  ┌─────────────┐  ┌─────────────┐                  │
│  │  PostgreSQL │  │    Redis    │                  │
│  │   Database  │  │    Cache    │                  │
│  └─────────────┘  └─────────────┘                  │
└─────────────────────────────────────────────────────┘
```

## Default Servers

- Matrix: `https://matrix.y7xyz.com`
- LiveKit: `wss://livekit.y7xyz.com`
- TURN: `turn.y7xyz.com`

## 📱 Client Apps

After server install, users can connect with:

### Official Clients
- **Element Web**: https://app.element.io (use your matrix server URL)
- **Element Desktop**: https://element.io/download
- **Element Mobile**: iOS App Store / Google Play

### Dragon Chat Clients (this repo)
Build from `/desktop` or `/mobile` folders, or download releases.

## 🔧 Manual Installation

```bash
# Clone repo
git clone https://github.com/yahyasaqban-lab/dragon-chat.git
cd dragon-chat

# Run installer
chmod +x install.sh
sudo ./install.sh --domain yourdomain.com
```

### Options
```bash
sudo ./install.sh --domain example.com --admin-user myadmin --admin-pass mypassword
```

| Flag | Description | Default |
|------|-------------|---------|
| `--domain` | Your domain | (required) |
| `--admin-user` | Matrix admin username | admin |
| `--admin-pass` | Matrix admin password | (random) |

## 🛠️ Management

```bash
# Check status
sudo systemctl status synapse livekit coturn

# View logs
sudo journalctl -u synapse -f
sudo journalctl -u livekit -f

# Restart services
sudo systemctl restart synapse livekit coturn

# Create new Matrix user
sudo docker exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```

## 🔒 Security Notes

- Change default admin password immediately
- Keep `/opt/dragon-chat/credentials.txt` secure
- Enable firewall: `sudo ufw enable`
- Regularly update: `sudo apt update && sudo apt upgrade`

## 📝 License

MIT

## 🙏 Credits

- [Matrix](https://matrix.org) - Chat protocol
- [Synapse](https://github.com/matrix-org/synapse) - Matrix server
- [LiveKit](https://livekit.io) - WebRTC infrastructure
- [Coturn](https://github.com/coturn/coturn) - TURN server

---

Created by [Yahya](https://github.com/yahyasaqban-lab) 🐉

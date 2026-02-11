# 🐉 Dragon Chat

A complete Discord alternative built on Matrix protocol with LiveKit for voice/video.

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

## License

MIT

---

Created by Dragon 🐉

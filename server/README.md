# 🐉 Matrix Discord Alternative

Full-featured Discord alternative with chat, voice, video, and streaming.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Dragon Communication                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Matrix Synapse     LiveKit          Coturn            │
│   ┌───────────┐     ┌───────────┐    ┌───────────┐     │
│   │ • Chat    │     │ • Voice   │    │ • TURN    │     │
│   │ • Rooms   │     │ • Video   │    │ • NAT     │     │
│   │ • E2EE    │     │ • Stream  │    │ • Relay   │     │
│   │ • Files   │     │ • Record  │    │           │     │
│   └───────────┘     └───────────┘    └───────────┘     │
│         │                 │                │            │
│         └─────────────────┼────────────────┘            │
│                           │                             │
│              ┌────────────▼────────────┐               │
│              │      Element Web        │               │
│              │    + LiveKit Widget     │               │
│              └─────────────────────────┘               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Features

- ✅ Text chat (Matrix)
- ✅ Voice channels (LiveKit)
- ✅ Video calls (LiveKit)
- ✅ Screen sharing (LiveKit)
- ✅ Live streaming (LiveKit)
- ✅ File sharing (Matrix)
- ✅ End-to-end encryption (Matrix)
- ✅ Federation (Matrix)
- ✅ Self-hosted
- ✅ Mobile apps (Element)

## Quick Start

```bash
# 1. Run the setup script
sudo bash scripts/01-install-all.sh

# 2. Configure your domain
nano configs/env.conf

# 3. Start services
sudo bash scripts/02-start-services.sh

# 4. Access
# Matrix: https://matrix.yourdomain.com
# Element: https://element.yourdomain.com
# LiveKit: wss://livekit.yourdomain.com
```

## Components

| Service | Port | Purpose |
|---------|------|---------|
| Synapse | 8008 | Matrix homeserver |
| Element | 80/443 | Web client |
| LiveKit | 7880/7881 | Voice/Video/Stream |
| Coturn | 3478/5349 | TURN relay (NAT traversal) |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |
| Nginx | 80/443 | Reverse proxy |

## Requirements

- Ubuntu 22.04+ or Debian 12+
- 4GB RAM minimum (8GB recommended)
- Domain with DNS access
- Ports: 80, 443, 3478, 5349, 7880, 7881

---
Created by Dragon 🐉 for Yahya

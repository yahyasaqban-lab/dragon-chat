#!/bin/bash
# Matrix Discord Alternative - Full Installation Script
# Run as: sudo bash 01-install-all.sh

set -e

echo "🐉 Matrix Discord Alternative Installer"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check root
if [ "$EUID" -ne 0 ]; then
    err "Please run as root (sudo)"
fi

# Load config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs"

if [ -f "$CONFIG_DIR/env.conf" ]; then
    source "$CONFIG_DIR/env.conf"
else
    warn "No env.conf found, using defaults"
    DOMAIN="example.com"
    MATRIX_DOMAIN="matrix.$DOMAIN"
    ELEMENT_DOMAIN="element.$DOMAIN"
    LIVEKIT_DOMAIN="livekit.$DOMAIN"
    TURN_DOMAIN="turn.$DOMAIN"
    ADMIN_EMAIL="admin@$DOMAIN"
fi

echo "Configuration:"
echo "  Domain: $DOMAIN"
echo "  Matrix: $MATRIX_DOMAIN"
echo "  Element: $ELEMENT_DOMAIN"
echo "  LiveKit: $LIVEKIT_DOMAIN"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# ===================
# DEPENDENCIES
# ===================
echo ""
echo "📦 Installing dependencies..."

apt update
apt install -y \
    curl \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    nginx \
    certbot \
    python3-certbot-nginx \
    postgresql \
    redis-server \
    coturn \
    jq \
    ufw

log "Dependencies installed"

# ===================
# DOCKER
# ===================
echo ""
echo "🐳 Installing Docker..."

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

log "Docker installed"

# ===================
# POSTGRESQL
# ===================
echo ""
echo "🗄️ Setting up PostgreSQL..."

sudo -u postgres psql -c "CREATE USER synapse WITH PASSWORD 'synapse_password';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE synapse OWNER synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' template=template0;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER livekit WITH PASSWORD 'livekit_password';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE livekit OWNER livekit;" 2>/dev/null || true

log "PostgreSQL configured"

# ===================
# CREATE DIRECTORIES
# ===================
echo ""
echo "📁 Creating directories..."

mkdir -p /opt/matrix-stack/{synapse,element,livekit,coturn,nginx}
mkdir -p /opt/matrix-stack/synapse/{data,config}
mkdir -p /opt/matrix-stack/element/config
mkdir -p /opt/matrix-stack/livekit/config
mkdir -p /var/log/matrix-stack

log "Directories created"

# ===================
# MATRIX SYNAPSE
# ===================
echo ""
echo "🔷 Installing Matrix Synapse..."

# Generate Synapse config
docker run -it --rm \
    -v /opt/matrix-stack/synapse/config:/data \
    -e SYNAPSE_SERVER_NAME=$MATRIX_DOMAIN \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate

# Update homeserver.yaml
cat >> /opt/matrix-stack/synapse/config/homeserver.yaml << EOF

# Database
database:
  name: psycopg2
  args:
    user: synapse
    password: synapse_password
    database: synapse
    host: localhost
    cp_min: 5
    cp_max: 10

# Enable registration
enable_registration: true
enable_registration_without_verification: true

# URL previews
url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'

# TURN server
turn_uris:
  - "turn:$TURN_DOMAIN:3478?transport=udp"
  - "turn:$TURN_DOMAIN:3478?transport=tcp"
turn_shared_secret: "$(openssl rand -hex 32)"
turn_user_lifetime: 86400000
turn_allow_guests: true

# Media
max_upload_size: 100M
EOF

log "Synapse configured"

# ===================
# LIVEKIT
# ===================
echo ""
echo "🎥 Installing LiveKit..."

LIVEKIT_API_KEY="API$(openssl rand -hex 12)"
LIVEKIT_API_SECRET="$(openssl rand -hex 32)"

cat > /opt/matrix-stack/livekit/config/livekit.yaml << EOF
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true

redis:
  address: localhost:6379

keys:
  $LIVEKIT_API_KEY: $LIVEKIT_API_SECRET

logging:
  level: info
  json: false

turn:
  enabled: true
  domain: $TURN_DOMAIN
  tls_port: 5349
  udp_port: 3478
  external_tls: true
EOF

# Save keys
cat > /opt/matrix-stack/livekit/config/keys.env << EOF
LIVEKIT_API_KEY=$LIVEKIT_API_KEY
LIVEKIT_API_SECRET=$LIVEKIT_API_SECRET
LIVEKIT_URL=wss://$LIVEKIT_DOMAIN
EOF

log "LiveKit configured"
echo "  API Key: $LIVEKIT_API_KEY"
echo "  API Secret: ${LIVEKIT_API_SECRET:0:10}..."

# ===================
# COTURN (TURN Server)
# ===================
echo ""
echo "🔄 Configuring Coturn..."

TURN_SECRET="$(openssl rand -hex 32)"

cat > /etc/turnserver.conf << EOF
# Network
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
external-ip=$(curl -s ifconfig.me)
relay-ip=0.0.0.0

# Domain
realm=$TURN_DOMAIN
server-name=$TURN_DOMAIN

# Authentication
use-auth-secret
static-auth-secret=$TURN_SECRET

# TLS (uncomment after getting certs)
# cert=/etc/letsencrypt/live/$TURN_DOMAIN/fullchain.pem
# pkey=/etc/letsencrypt/live/$TURN_DOMAIN/privkey.pem

# Logging
log-file=/var/log/turnserver.log
verbose

# Security
no-multicast-peers
no-cli
no-tcp-relay

# Quotas
user-quota=12
total-quota=1200
EOF

systemctl enable coturn
systemctl restart coturn

log "Coturn configured"

# ===================
# ELEMENT WEB
# ===================
echo ""
echo "🌐 Installing Element Web..."

ELEMENT_VERSION="v1.11.57"
cd /opt/matrix-stack/element
wget -q "https://github.com/vector-im/element-web/releases/download/$ELEMENT_VERSION/element-$ELEMENT_VERSION.tar.gz"
tar -xzf element-$ELEMENT_VERSION.tar.gz
mv element-$ELEMENT_VERSION web
rm element-$ELEMENT_VERSION.tar.gz

cat > /opt/matrix-stack/element/web/config.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$MATRIX_DOMAIN",
            "server_name": "$MATRIX_DOMAIN"
        }
    },
    "brand": "Dragon Chat",
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "bug_report_endpoint_url": "",
    "show_labs_settings": true,
    "features": {
        "feature_video_rooms": true,
        "feature_group_calls": true,
        "feature_element_call_video_rooms": true
    },
    "element_call": {
        "url": "https://call.element.io",
        "participant_limit": 8,
        "brand": "Element Call"
    },
    "voip": {
        "obey_asserted_identity": true
    },
    "setting_defaults": {
        "custom_themes": [],
        "use_system_theme": false,
        "theme": "dark"
    },
    "room_directory": {
        "servers": ["$MATRIX_DOMAIN"]
    }
}
EOF

log "Element Web installed"

# ===================
# NGINX
# ===================
echo ""
echo "🌍 Configuring Nginx..."

cat > /etc/nginx/sites-available/matrix-stack << EOF
# Matrix Synapse
server {
    listen 80;
    server_name $MATRIX_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $MATRIX_DOMAIN;

    # SSL will be configured by certbot
    
    location ~ ^(/_matrix|/_synapse/client) {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        client_max_body_size 100M;
    }
}

# Element Web
server {
    listen 80;
    server_name $ELEMENT_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $ELEMENT_DOMAIN;

    root /opt/matrix-stack/element/web;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

# LiveKit
server {
    listen 80;
    server_name $LIVEKIT_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $LIVEKIT_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400;
    }
}

# TURN Server (for .well-known)
server {
    listen 80;
    server_name $TURN_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $TURN_DOMAIN;

    location / {
        return 200 'TURN Server';
        add_header Content-Type text/plain;
    }
}
EOF

ln -sf /etc/nginx/sites-available/matrix-stack /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx

log "Nginx configured"

# ===================
# DOCKER COMPOSE
# ===================
echo ""
echo "🐳 Creating Docker Compose..."

cat > /opt/matrix-stack/docker-compose.yml << EOF
version: '3.8'

services:
  synapse:
    image: matrixdotorg/synapse:latest
    container_name: synapse
    restart: unless-stopped
    volumes:
      - ./synapse/config:/data
      - ./synapse/data:/data/media_store
    network_mode: host
    environment:
      - SYNAPSE_CONFIG_PATH=/data/homeserver.yaml

  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit
    restart: unless-stopped
    volumes:
      - ./livekit/config/livekit.yaml:/etc/livekit.yaml
    network_mode: host
    command: --config /etc/livekit.yaml

  # Optional: LiveKit Egress (recording/streaming)
  livekit-egress:
    image: livekit/egress:latest
    container_name: livekit-egress
    restart: unless-stopped
    environment:
      - EGRESS_CONFIG_FILE=/etc/egress.yaml
    volumes:
      - ./livekit/config/egress.yaml:/etc/egress.yaml
      - ./livekit/recordings:/recordings
    cap_add:
      - SYS_ADMIN
    network_mode: host
EOF

log "Docker Compose created"

# ===================
# FIREWALL
# ===================
echo ""
echo "🔥 Configuring firewall..."

ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 3478/tcp    # TURN TCP
ufw allow 3478/udp    # TURN UDP
ufw allow 5349/tcp    # TURN TLS
ufw allow 5349/udp    # TURN DTLS
ufw allow 7880/tcp    # LiveKit API
ufw allow 7881/tcp    # LiveKit RTC
ufw allow 50000:60000/udp  # LiveKit media

ufw --force enable

log "Firewall configured"

# ===================
# SAVE CONFIG
# ===================
echo ""
echo "💾 Saving configuration..."

cat > /opt/matrix-stack/config-summary.txt << EOF
===========================================
Matrix Discord Alternative - Configuration
===========================================

DOMAINS:
  Matrix: https://$MATRIX_DOMAIN
  Element: https://$ELEMENT_DOMAIN
  LiveKit: wss://$LIVEKIT_DOMAIN
  TURN: $TURN_DOMAIN

LIVEKIT CREDENTIALS:
  API Key: $LIVEKIT_API_KEY
  API Secret: $LIVEKIT_API_SECRET
  URL: wss://$LIVEKIT_DOMAIN

TURN SERVER:
  Secret: $TURN_SECRET
  Ports: 3478 (UDP/TCP), 5349 (TLS)

DATABASE:
  Synapse: synapse / synapse_password
  LiveKit: livekit / livekit_password

FILES:
  Synapse config: /opt/matrix-stack/synapse/config/
  LiveKit config: /opt/matrix-stack/livekit/config/
  Element: /opt/matrix-stack/element/web/
  Nginx: /etc/nginx/sites-available/matrix-stack
  Coturn: /etc/turnserver.conf

COMMANDS:
  Start: docker-compose -f /opt/matrix-stack/docker-compose.yml up -d
  Stop: docker-compose -f /opt/matrix-stack/docker-compose.yml down
  Logs: docker-compose -f /opt/matrix-stack/docker-compose.yml logs -f
  
Created: $(date)
===========================================
EOF

cat /opt/matrix-stack/config-summary.txt

# ===================
# NEXT STEPS
# ===================
echo ""
echo "======================================"
echo "✅ Installation Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Update DNS records:"
echo "   A record: $MATRIX_DOMAIN → $(curl -s ifconfig.me)"
echo "   A record: $ELEMENT_DOMAIN → $(curl -s ifconfig.me)"
echo "   A record: $LIVEKIT_DOMAIN → $(curl -s ifconfig.me)"
echo "   A record: $TURN_DOMAIN → $(curl -s ifconfig.me)"
echo ""
echo "2. Get SSL certificates:"
echo "   sudo certbot --nginx -d $MATRIX_DOMAIN -d $ELEMENT_DOMAIN -d $LIVEKIT_DOMAIN -d $TURN_DOMAIN"
echo ""
echo "3. Start services:"
echo "   cd /opt/matrix-stack && docker-compose up -d"
echo ""
echo "4. Create admin user:"
echo "   docker exec -it synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008 -a"
echo ""
echo "Configuration saved to: /opt/matrix-stack/config-summary.txt"
echo ""
echo "🐉 Enjoy your Discord alternative!"

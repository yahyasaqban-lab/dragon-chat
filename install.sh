#!/bin/bash
# 🐉 Dragon Chat - One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/yahyasaqban-lab/dragon-chat/master/install.sh | bash -s -- --domain your-domain.com

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "🐉 =================================================="
echo "   Dragon Chat Installer"
echo "   Discord Alternative (Matrix + LiveKit)"
echo "==================================================${NC}"
echo ""

# Parse arguments
DOMAIN=""
ADMIN_USER="admin"
ADMIN_PASS=""
LIVEKIT_KEY=""
LIVEKIT_SECRET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        --admin-user) ADMIN_USER="$2"; shift 2 ;;
        --admin-pass) ADMIN_PASS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Interactive mode if no domain
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain (e.g., y7xyz.com): " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain is required${NC}"
    exit 1
fi

MATRIX_DOMAIN="matrix.$DOMAIN"
LIVEKIT_DOMAIN="livekit.$DOMAIN"
TURN_DOMAIN="turn.$DOMAIN"

echo -e "${GREEN}Installing Dragon Chat for: $DOMAIN${NC}"
echo "  Matrix:  $MATRIX_DOMAIN"
echo "  LiveKit: $LIVEKIT_DOMAIN"
echo "  TURN:    $TURN_DOMAIN"
echo ""

# Generate secrets if not provided
if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
fi
LIVEKIT_KEY=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 12)
LIVEKIT_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
TURN_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
POSTGRES_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

# Update system
echo -e "${YELLOW}[1/7] Updating system...${NC}"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install dependencies
echo -e "${YELLOW}[2/7] Installing dependencies...${NC}"
sudo apt-get install -y -qq \
    docker.io docker-compose-v2 \
    nginx certbot python3-certbot-nginx \
    postgresql postgresql-contrib \
    redis-server \
    curl wget git jq

# Start services
sudo systemctl enable --now docker postgresql redis-server nginx

# Clone repo
echo -e "${YELLOW}[3/7] Downloading Dragon Chat...${NC}"
cd /opt
sudo rm -rf dragon-chat
sudo git clone https://github.com/yahyasaqban-lab/dragon-chat.git
cd dragon-chat

# Setup PostgreSQL
echo -e "${YELLOW}[4/7] Setting up database...${NC}"
sudo -u postgres psql -c "CREATE USER synapse WITH PASSWORD '$POSTGRES_PASS';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE synapse OWNER synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;" 2>/dev/null || true

# Create Synapse config
echo -e "${YELLOW}[5/7] Configuring Matrix (Synapse)...${NC}"
sudo mkdir -p /etc/synapse /var/lib/synapse/media_store
SYNAPSE_SECRET=$(openssl rand -base64 32)
MACAROON_SECRET=$(openssl rand -base64 32)
FORM_SECRET=$(openssl rand -base64 32)

sudo tee /etc/synapse/homeserver.yaml > /dev/null << SYNAPSE_EOF
server_name: "$DOMAIN"
pid_file: /var/lib/synapse/homeserver.pid
listeners:
  - port: 8008
    type: http
    resources:
      - names: [client, federation]
database:
  name: psycopg2
  args:
    user: synapse
    password: $POSTGRES_PASS
    database: synapse
    host: localhost
    cp_min: 5
    cp_max: 10
log_config: "/etc/synapse/log.yaml"
media_store_path: /var/lib/synapse/media_store
registration_shared_secret: "$SYNAPSE_SECRET"
macaroon_secret_key: "$MACAROON_SECRET"
form_secret: "$FORM_SECRET"
enable_registration: true
enable_registration_without_verification: true
report_stats: false
trusted_key_servers:
  - server_name: "matrix.org"
SYNAPSE_EOF

sudo tee /etc/synapse/log.yaml > /dev/null << 'LOG_EOF'
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
root:
  level: INFO
  handlers: [console]
LOG_EOF

# Run Synapse with Docker
echo -e "${YELLOW}[6/7] Starting services...${NC}"
sudo docker pull matrixdotorg/synapse:latest

# Create systemd service for Synapse
sudo tee /etc/systemd/system/synapse.service > /dev/null << SERVICE_EOF
[Unit]
Description=Matrix Synapse
After=docker.service postgresql.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker stop synapse
ExecStartPre=-/usr/bin/docker rm synapse
ExecStart=/usr/bin/docker run --name synapse --rm \\
    -v /etc/synapse:/data:ro \\
    -v /var/lib/synapse:/var/lib/synapse \\
    --network host \\
    matrixdotorg/synapse:latest
ExecStop=/usr/bin/docker stop synapse

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# LiveKit
sudo docker pull livekit/livekit-server:latest

sudo mkdir -p /etc/livekit
sudo tee /etc/livekit/config.yaml > /dev/null << LIVEKIT_EOF
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
turn:
  enabled: true
  domain: $TURN_DOMAIN
  tls_port: 5349
  udp_port: 3478
  external_tls: true
keys:
  $LIVEKIT_KEY: $LIVEKIT_SECRET
LIVEKIT_EOF

sudo tee /etc/systemd/system/livekit.service > /dev/null << SERVICE_EOF
[Unit]
Description=LiveKit Server
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker stop livekit
ExecStartPre=-/usr/bin/docker rm livekit
ExecStart=/usr/bin/docker run --name livekit --rm \\
    -v /etc/livekit:/etc/livekit:ro \\
    --network host \\
    livekit/livekit-server:latest \\
    --config /etc/livekit/config.yaml
ExecStop=/usr/bin/docker stop livekit

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Coturn
sudo apt-get install -y -qq coturn
sudo tee /etc/turnserver.conf > /dev/null << TURN_EOF
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=$TURN_SECRET
realm=$DOMAIN
total-quota=100
stale-nonce
cert=/etc/letsencrypt/live/$TURN_DOMAIN/fullchain.pem
pkey=/etc/letsencrypt/live/$TURN_DOMAIN/privkey.pem
no-loopback-peers
no-multicast-peers
TURN_EOF

# Nginx config
sudo tee /etc/nginx/sites-available/dragon-chat > /dev/null << NGINX_EOF
# Matrix
server {
    listen 80;
    server_name $MATRIX_DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        client_max_body_size 50M;
    }
    
    location /.well-known/matrix/server {
        return 200 '{"m.server": "$MATRIX_DOMAIN:443"}';
        add_header Content-Type application/json;
    }
    
    location /.well-known/matrix/client {
        return 200 '{"m.homeserver": {"base_url": "https://$MATRIX_DOMAIN"}}';
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
    }
}

# LiveKit
server {
    listen 80;
    server_name $LIVEKIT_DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

# TURN (for HTTPS redirect)
server {
    listen 80;
    server_name $TURN_DOMAIN;
    location / { return 301 https://\$host\$request_uri; }
}
NGINX_EOF

sudo ln -sf /etc/nginx/sites-available/dragon-chat /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# SSL Certificates
echo -e "${YELLOW}[7/7] Setting up SSL certificates...${NC}"
sudo certbot --nginx -d $MATRIX_DOMAIN -d $LIVEKIT_DOMAIN -d $TURN_DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || {
    echo -e "${YELLOW}Certbot failed - you may need to set up DNS first${NC}"
    echo "Run manually: sudo certbot --nginx -d $MATRIX_DOMAIN -d $LIVEKIT_DOMAIN -d $TURN_DOMAIN"
}

# Start services
sudo systemctl daemon-reload
sudo systemctl enable --now synapse livekit coturn

# Create admin user
sleep 5
sudo docker exec synapse register_new_matrix_user -u $ADMIN_USER -p $ADMIN_PASS -a -c /data/homeserver.yaml http://localhost:8008 2>/dev/null || {
    echo -e "${YELLOW}Admin user creation will be done after services start${NC}"
}

# Save credentials
CREDS_FILE="/opt/dragon-chat/credentials.txt"
sudo tee $CREDS_FILE > /dev/null << CREDS_EOF
🐉 Dragon Chat Credentials
===========================

Domain: $DOMAIN

Matrix Server:
  URL: https://$MATRIX_DOMAIN
  Admin User: $ADMIN_USER
  Admin Pass: $ADMIN_PASS
  Registration Secret: $SYNAPSE_SECRET

LiveKit Server:
  URL: wss://$LIVEKIT_DOMAIN
  API Key: $LIVEKIT_KEY
  API Secret: $LIVEKIT_SECRET

TURN Server:
  Host: $TURN_DOMAIN
  Secret: $TURN_SECRET

Database:
  PostgreSQL Password: $POSTGRES_PASS

⚠️ KEEP THIS FILE SECURE!
CREDS_EOF

sudo chmod 600 $CREDS_FILE

# Print summary
echo ""
echo -e "${GREEN}🐉 Dragon Chat installed successfully!${NC}"
echo ""
echo "=================================="
echo "  IMPORTANT CREDENTIALS"
echo "=================================="
echo ""
echo -e "Matrix Server:  ${BLUE}https://$MATRIX_DOMAIN${NC}"
echo -e "LiveKit Server: ${BLUE}wss://$LIVEKIT_DOMAIN${NC}"
echo -e "TURN Server:    ${BLUE}$TURN_DOMAIN${NC}"
echo ""
echo -e "Admin User: ${GREEN}$ADMIN_USER${NC}"
echo -e "Admin Pass: ${GREEN}$ADMIN_PASS${NC}"
echo ""
echo -e "LiveKit Key:    ${YELLOW}$LIVEKIT_KEY${NC}"
echo -e "LiveKit Secret: ${YELLOW}$LIVEKIT_SECRET${NC}"
echo ""
echo "Full credentials saved to: $CREDS_FILE"
echo ""
echo "=================================="
echo "  REQUIRED DNS RECORDS"
echo "=================================="
echo ""
echo "Add these A records pointing to this server's IP:"
echo "  $MATRIX_DOMAIN  → $(curl -s ifconfig.me)"
echo "  $LIVEKIT_DOMAIN → $(curl -s ifconfig.me)"
echo "  $TURN_DOMAIN    → $(curl -s ifconfig.me)"
echo ""
echo "=================================="
echo "  NEXT STEPS"
echo "=================================="
echo "1. Set up DNS records above"
echo "2. Run: sudo certbot --nginx -d $MATRIX_DOMAIN -d $LIVEKIT_DOMAIN -d $TURN_DOMAIN"
echo "3. Open firewall: sudo ufw allow 80,443,3478,5349,7880,7881/tcp"
echo "4. Open firewall: sudo ufw allow 3478,50000:60000/udp"
echo "5. Test: curl https://$MATRIX_DOMAIN/_matrix/client/versions"
echo ""
echo -e "${GREEN}🐉 Enjoy Dragon Chat!${NC}"

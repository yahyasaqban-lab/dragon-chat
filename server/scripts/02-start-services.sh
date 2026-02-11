#!/bin/bash
# Start all Matrix Stack services

echo "🐉 Starting Matrix Stack..."

cd /opt/matrix-stack

# Start Redis
systemctl start redis-server

# Start Coturn
systemctl start coturn

# Start Docker containers
docker-compose up -d

# Check status
echo ""
echo "Service Status:"
echo "==============="
systemctl status redis-server --no-pager | head -5
systemctl status coturn --no-pager | head -5
docker-compose ps

echo ""
echo "✅ All services started!"
echo ""
echo "Access:"
echo "  Element: https://element.$(grep DOMAIN configs/env.conf | head -1 | cut -d'"' -f2)"
echo "  Matrix: https://matrix.$(grep DOMAIN configs/env.conf | head -1 | cut -d'"' -f2)"

#!/bin/bash
# Create Matrix admin user

echo "🐉 Create Matrix Admin User"
echo "==========================="
echo ""

read -p "Username: " username
read -s -p "Password: " password
echo ""

docker exec -it synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u "$username" \
    -p "$password" \
    -a \
    http://localhost:8008

echo ""
echo "✅ Admin user created: @$username:$(grep server_name /opt/matrix-stack/synapse/config/homeserver.yaml | head -1 | awk '{print $2}')"

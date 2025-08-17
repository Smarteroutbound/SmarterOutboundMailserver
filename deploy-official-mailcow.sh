#!/bin/bash
set -e

DOMAIN="${1:-mail.smarteroutbound.com}"
MAILCOW_DIR="/opt/mailcow-dockerized"

echo "🚀 Deploying Official Mailcow for $DOMAIN"

[[ $EUID -ne 0 ]] && { echo "❌ Run as root"; exit 1; }

# Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh || { echo "❌ Docker install failed"; exit 1; }
    systemctl enable --now docker
fi

# Clone official mailcow
if [[ ! -d "$MAILCOW_DIR" ]]; then
    git clone https://github.com/mailcow/mailcow-dockerized.git "$MAILCOW_DIR" || { echo "❌ Clone failed"; exit 1; }
fi

cd "$MAILCOW_DIR"

# Generate config
[[ ! -f "mailcow.conf" ]] && echo "$DOMAIN" | ./generate_config.sh

# Start services
echo "🚀 Starting mailcow services..."
docker-compose pull || { echo "❌ Pull failed"; exit 1; }
docker-compose up -d || { echo "❌ Start failed"; exit 1; }

# Health check
echo "⏳ Waiting for services..."
timeout=300
counter=0
while [[ $counter -lt $timeout ]]; do
    if docker-compose ps | grep -q "Up"; then
        echo "✅ Services running"
        break
    fi
    sleep 5
    counter=$((counter + 5))
done

echo "🎉 Mailcow deployed!"
echo "📧 Access: https://$DOMAIN"
echo "🔧 Admin: https://$DOMAIN/admin"
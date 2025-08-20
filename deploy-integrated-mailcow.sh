#!/bin/bash
set -e

DOMAIN="${1:-mail.smarteroutbound.com}"
MAILCOW_DIR="/opt/mailcow-dockerized"
KUMOMTA_DIR="/opt/kumomta-integration-new"
OVERRIDE_FILE="$(dirname "$0")/docker-compose.override.yml"

echo "🚀 Deploying Integrated Mailcow + KumoMTA for $DOMAIN"

[[ $EUID -ne 0 ]] && { echo "❌ Run as root"; exit 1; }

# Check if KumoMTA is already running
if [[ ! -d "$KUMOMTA_DIR" ]]; then
    echo "❌ KumoMTA directory not found at $KUMOMTA_DIR"
    echo "   Please deploy KumoMTA first using the kumomta-integration-new setup"
    exit 1
fi

# Start KumoMTA first to create the network
echo "🔧 Starting KumoMTA services..."
cd "$KUMOMTA_DIR"
docker-compose up -d
echo "✅ KumoMTA services started"

# Wait for KumoMTA to be healthy
echo "⏳ Waiting for KumoMTA to be ready..."
timeout=120
counter=0
while [[ $counter -lt $timeout ]]; do
    if docker-compose ps | grep -q "Up" && docker-compose ps | grep -q "healthy"; then
        echo "✅ KumoMTA is healthy"
        break
    fi
    sleep 5
    counter=$((counter + 5))
done

# Clone official mailcow if not exists
if [[ ! -d "$MAILCOW_DIR" ]]; then
    echo "📥 Cloning official Mailcow..."
    git clone https://github.com/mailcow/mailcow-dockerized.git "$MAILCOW_DIR"
fi

cd "$MAILCOW_DIR"

# Generate config if not exists
if [[ ! -f "mailcow.conf" ]]; then
    echo "⚙️  Generating Mailcow configuration..."
    echo "$DOMAIN" | ./generate_config.sh
fi

# Copy our override file
if [[ -f "$OVERRIDE_FILE" ]]; then
    cp "$OVERRIDE_FILE" ./docker-compose.override.yml
    echo "✅ KumoMTA integration override applied"
fi

# Start Mailcow services
echo "🚀 Starting Mailcow services..."
docker-compose pull
docker-compose up -d

# Health check
echo "⏳ Waiting for Mailcow services..."
timeout=300
counter=0
while [[ $counter -lt $timeout ]]; do
    if docker-compose ps | grep -q "Up"; then
        echo "✅ Mailcow services running"
        break
    fi
    sleep 5
    counter=$((counter + 5))
done

# Test the integration
echo "🧪 Testing KumoMTA integration..."
if docker exec postfix-mailcow postconf -h relayhost | grep -q "kumod-enterprise:25"; then
    echo "✅ Postfix configured to relay through KumoMTA"
else
    echo "❌ Postfix relay configuration failed"
    exit 1
fi

echo "🎉 Integrated deployment complete!"
echo "📧 Mailcow: https://$DOMAIN"
echo "🔧 Admin: https://$DOMAIN/admin"
echo "📨 SMTP Relay: KumoMTA on port 25"
echo "📊 KumoMTA Dashboard: http://localhost:8000"
echo ""
echo "🔗 Next steps:"
echo "   1. Configure DNS records for $DOMAIN"
echo "   2. Set up SSL certificates"
echo "   3. Create admin user in Mailcow"
echo "   4. Test email delivery through KumoMTA"

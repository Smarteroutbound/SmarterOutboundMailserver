#!/bin/bash
set -e

DOMAIN="${1:-149.28.244.166}"
MAILCOW_DIR="/opt/mailcow-dockerized"
KUMOMTA_SERVER="${2:-89.117.75.190}"
OVERRIDE_FILE="$(dirname "$0")/docker-compose.override.yml"
CONFIG_FILE="$(dirname "$0")/mailcow.conf"

echo "🚀 Deploying Integrated Mailcow + KumoMTA for $DOMAIN"
echo "📡 KumoMTA Server: $KUMOMTA_SERVER"
echo "📍 Real IP Configuration - No Docker Networks Needed"

[[ $EUID -ne 0 ]] && { echo "❌ Run as root"; exit 1; }

# Skip network creation - using real IPs
echo "🌐 Using real IP addresses - no Docker network needed"

# Test KumoMTA connectivity
echo "🔍 Testing KumoMTA connectivity..."
if ! ping -c 1 $KUMOMTA_SERVER > /dev/null 2>&1; then
    echo "⚠️  Warning: Cannot ping $KUMOMTA_SERVER"
    echo "   Mailcow will still deploy but email relay may not work"
    echo "   Ensure KumoMTA is running and accessible"
else
    echo "✅ KumoMTA server is reachable"
fi

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

# Copy our configuration
if [[ -f "$CONFIG_FILE" ]]; then
    echo "⚙️  Using custom Mailcow configuration..."
    cp "$CONFIG_FILE" ./mailcow.conf
    # Update domain in config
    sed -i "s/MAILCOW_HOSTNAME=.*/MAILCOW_HOSTNAME=$DOMAIN/g" ./mailcow.conf
else
    # Generate config if not exists
    if [[ ! -f "mailcow.conf" ]]; then
        echo "⚙️  Generating Mailcow configuration..."
        echo "$DOMAIN" | ./generate_config.sh
    fi
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
if docker exec postfix-mailcow postconf -h relayhost | grep -q "89.117.75.190:25"; then
    echo "✅ Postfix configured to relay through KumoMTA"
else
    echo "⚠️  Postfix relay configuration may need manual verification"
    echo "   Expected: 89.117.75.190:25"
    echo "   Actual: $(docker exec postfix-mailcow postconf -h relayhost)"
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

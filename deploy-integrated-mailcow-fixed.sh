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

# Test KumoMTA connectivity
echo "🔍 Testing KumoMTA connectivity..."
if ! ping -c 1 $KUMOMTA_SERVER > /dev/null 2>&1; then
    echo "⚠️  Warning: Cannot ping $KUMOMTA_SERVER"
    echo "   Mailcow will still deploy but email relay may not work"
else
    echo "✅ KumoMTA server is reachable"
fi

# Test KumoMTA SMTP (simplified)
echo "⏳ Testing KumoMTA SMTP..."
if nc -z -w5 $KUMOMTA_SERVER 25 2>/dev/null; then
    echo "✅ KumoMTA SMTP port is open"
else
    echo "⚠️  KumoMTA SMTP port not accessible - continuing anyway"
fi

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

# Simple health check
echo "⏳ Waiting for Mailcow services..."
sleep 60

# Check if containers are running
if docker-compose ps | grep -q "Up"; then
    echo "✅ Mailcow services are running"
else
    echo "⚠️  Some Mailcow services may not be running properly"
fi

# Test the integration
echo "🧪 Testing KumoMTA integration..."
sleep 30
if docker exec postfix-mailcow postconf -h relayhost 2>/dev/null | grep -q "89.117.75.190:25"; then
    echo "✅ Postfix configured to relay through KumoMTA"
else
    echo "⚠️  Postfix relay configuration may need manual verification"
fi

echo "🎉 Integrated deployment complete!"
echo "📧 Mailcow: https://$DOMAIN"
echo "🔧 Admin: https://$DOMAIN/admin"
echo "📨 SMTP Relay: KumoMTA on $KUMOMTA_SERVER:25"
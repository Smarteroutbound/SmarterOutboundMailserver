#!/bin/bash
# Update Mailcow configuration for KumoMTA integration

MAILCOW_DIR="/opt/mailcow-dockerized"
API_KEY="a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"

echo "🔧 Updating Mailcow configuration..."

# Backup original config
cp $MAILCOW_DIR/mailcow.conf $MAILCOW_DIR/mailcow.conf.backup

# Update API configuration
sed -i "s/^API_KEY=.*/API_KEY=$API_KEY/" $MAILCOW_DIR/mailcow.conf
sed -i "s/^#API_ALLOW_FROM=.*/API_ALLOW_FROM=172.22.1.1,127.0.0.1,0.0.0.0\/0/" $MAILCOW_DIR/mailcow.conf

# Create header injection for KumoMTA
mkdir -p $MAILCOW_DIR/data/conf/postfix
echo '/^/ PREPEND X-Kumo-Authenticated-User: ${sasl_username}' > $MAILCOW_DIR/data/conf/postfix/custom_header_checks.pcre

# Add header checks to postfix config
echo 'smtp_header_checks = pcre:/opt/postfix/conf/custom_header_checks.pcre' >> $MAILCOW_DIR/data/conf/postfix/main.cf

# Apply KumoMTA override
cp docker-compose.override.yml $MAILCOW_DIR/

echo "✅ Configuration updated!"
echo "🔄 Restarting Mailcow services..."

cd $MAILCOW_DIR
docker-compose down
docker-compose up -d

echo "🎉 Mailcow updated for KumoMTA integration!"
echo "📝 API Key: $API_KEY"
echo "🔗 Add this to your Django .env: MAILCOW_API_KEY=$API_KEY"
# Mailcow Development - Email Server

Official Mailcow-Dockerized deployment with custom configurations.

## Quick Deploy

```bash
chmod +x deploy-official-mailcow.sh
sudo ./deploy-official-mailcow.sh mail.yourdomain.com
```

## What This Does

1. Clones official mailcow-dockerized
2. Runs their generate_config.sh
3. Starts all mailcow services
4. Configures DNS and SSL

## Access

- Web Interface: https://mail.yourdomain.com
- Admin Panel: https://mail.yourdomain.com/admin
- API: https://mail.yourdomain.com/api/v1/

## DNS Setup Required

```dns
mail.yourdomain.com    A    YOUR_SERVER_IP
yourdomain.com         MX   10 mail.yourdomain.com
yourdomain.com         TXT  "v=spf1 mx ~all"
```
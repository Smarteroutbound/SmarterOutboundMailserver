# 🚀 Complete Mailcow + KumoMTA Integration Deployment Guide

## 🎯 Overview

This guide deploys a **complete, integrated email platform** that combines:
- **Mailcow**: User management, domains, web interface
- **KumoMTA**: High-performance email delivery, IP rotation, monitoring
- **Django Integration**: Unified API access and management

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Django App    │    │     Mailcow      │    │    KumoMTA      │
│                 │    │                  │    │                 │
│ • User Mgmt     │◄──►│ • Web Interface  │    │ • SMTP Server   │
│ • Domain Mgmt   │    │ • API Endpoints  │    │ • IP Rotation   │
│ • Credentials   │    │ • Postfix        │    │ • Rate Limiting │
│ • Integration   │    │ • Dovecot        │    │ • Monitoring    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │   Shared        │              │
         └──────────────►│   Network      │◄─────────────┘
                        │   (kumo-network)│
                        └─────────────────┘
```

## 📋 Prerequisites

- **Server**: Ubuntu 20.04+ or CentOS 8+
- **Docker**: Version 24.0.0+
- **Docker Compose**: Version 2.0.0+
- **Domain**: Configured with DNS records
- **Root Access**: Required for deployment

## 🔧 Deployment Steps

### 1. Deploy KumoMTA First

```bash
cd /opt/kumomta-integration-new
docker-compose up -d
```

**Wait for all services to be healthy:**
```bash
docker-compose ps
```

### 2. Deploy Mailcow with Integration

```bash
cd /opt/mailcow-development
chmod +x deploy-integrated-mailcow.sh
sudo ./deploy-integrated-mailcow.sh mail.yourdomain.com
```

### 3. Verify Integration

```bash
# Check Mailcow is using KumoMTA as relay
docker exec postfix-mailcow postconf -h relayhost

# Should show: kumod-enterprise:25
```

## 🌐 DNS Configuration

```dns
# Main mail server
mail.yourdomain.com    A    YOUR_SERVER_IP

# Email routing
yourdomain.com         MX   10 mail.yourdomain.com

# Email authentication
yourdomain.com         TXT  "v=spf1 mx ~all"
yourdomain.com         TXT  "v=DKIM1; k=rsa; p=YOUR_DKIM_KEY"
yourdomain.com         TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

## 🔐 Environment Variables

### Django (.env)
```bash
# Mailcow Integration
MAILCOW_BASE_URL=https://mail.yourdomain.com
MAILCOW_API_KEY=your_mailcow_api_key
MAILCOW_VERIFY_SSL=true

# KumoMTA Integration  
KUMOMTA_BASE_URL=http://localhost:8000
KUMOMTA_API_KEY=your_kumomta_api_key
KUMOMTA_VERIFY_SSL=false
```

### Mailcow (mailcow.conf)
```bash
# Generated automatically by generate_config.sh
# Key settings:
MAILCOW_HOSTNAME=mail.yourdomain.com
API_KEY=your_api_key_here
API_ALLOW_FROM=0.0.0.0/0
```

## 📱 API Integration

### Python/Django Usage

```python
from django_integration import get_integration_from_django_settings

# Get integration instance
integration = get_integration_from_django_settings()

# Create user for cold email
result = integration.setup_user_for_cold_email(
    username="user@domain.com",
    password="securepassword",
    domain="domain.com"
)

# Check system health
health = integration.get_system_health()
```

### API Endpoints

#### Mailcow API
- **Base URL**: `https://mail.yourdomain.com/api/v1/`
- **Authentication**: `X-API-Key` header
- **Endpoints**: `/add/mailbox`, `/get/domain/all`, etc.

#### KumoMTA API
- **Base URL**: `http://localhost:8000/`
- **Endpoints**: `/health`, `/metrics`, `/stats/delivery`

## 🔄 Email Flow

### 1. User Registration (Django)
```
Django → Mailcow API → Create Mailbox → Return Credentials
```

### 2. Email Sending (Client)
```
Email Client → Mailcow (Port 587) → Postfix → KumoMTA (Port 25) → Internet
```

### 3. Email Receiving (Client)
```
Internet → Mailcow (Port 25) → Dovecot → Email Client (Port 993)
```

## 📊 Monitoring

### KumoMTA Dashboard
- **URL**: `http://localhost:8000`
- **Features**: Delivery stats, IP rotation, performance metrics

### Mailcow Admin
- **URL**: `https://mail.yourdomain.com/admin`
- **Features**: User management, domain settings, logs

### Prometheus + Grafana
- **Prometheus**: `http://localhost:9090`
- **Grafana**: `http://localhost:3000`
- **Features**: System metrics, alerting, dashboards

## 🚨 Troubleshooting

### Common Issues

#### 1. Network Connection Failed
```bash
# Check if KumoMTA network exists
docker network ls | grep kumo-network

# Check Mailcow can reach KumoMTA
docker exec postfix-mailcow ping kumod-enterprise
```

#### 2. Relay Host Error
```bash
# Verify Postfix configuration
docker exec postfix-mailcow postconf -h relayhost

# Check KumoMTA logs
docker logs kumod-enterprise
```

#### 3. API Authentication Failed
```bash
# Test Mailcow API
curl -H "X-API-Key: YOUR_KEY" \
     https://mail.yourdomain.com/api/v1/get/domain/all

# Test KumoMTA API
curl http://localhost:8000/health
```

### Health Checks

```bash
# Overall system health
python3 django-integration.py

# Individual service health
docker-compose ps
docker exec kumod-enterprise curl -f http://localhost:8000/health
```

## 🔒 Security Considerations

1. **API Keys**: Use strong, unique keys for each service
2. **Network Isolation**: Services communicate only on internal network
3. **SSL/TLS**: Enable for all external communications
4. **Rate Limiting**: KumoMTA provides built-in protection
5. **Monitoring**: Set up alerts for unusual activity

## 📈 Scaling

### Horizontal Scaling
- **KumoMTA**: Add more instances behind load balancer
- **Mailcow**: Use clustering for high availability
- **Database**: Implement replication for MariaDB

### Performance Tuning
- **Redis**: Increase memory limits for high throughput
- **Postfix**: Adjust connection limits and queue sizes
- **Dovecot**: Optimize for concurrent connections

## 🆘 Support

### Logs Location
- **Mailcow**: `/opt/mailcow-dockerized/data/log/`
- **KumoMTA**: `/opt/kumomta-integration-new/logs/`
- **Django**: Application logs

### Documentation
- **Mailcow**: https://docs.mailcow.email/
- **KumoMTA**: https://docs.kumomta.com/
- **Integration**: This guide + code comments

---

## 🎉 Success!

Once deployed, you'll have:
- ✅ **Complete email platform** with user management
- ✅ **High-performance delivery** through KumoMTA
- ✅ **Unified API access** for Django integration
- ✅ **Professional monitoring** and alerting
- ✅ **Production-ready** architecture

Your clients can now use email sequencers like Instantly with the SMTP/IMAP credentials provided by your system! 🚀

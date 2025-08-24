#!/usr/bin/env python3
"""
Django Integration Script for Mailcow + KumoMTA
Provides unified API access to both systems
"""

import requests
import json
import os
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class MailcowConfig:
    """Mailcow configuration"""
    base_url: str
    api_key: str
    verify_ssl: bool = True

@dataclass
class KumoMTAConfig:
    """KumoMTA configuration"""
    base_url: str
    api_key: Optional[str] = None
    verify_ssl: bool = False

class MailcowKumoIntegration:
    """Unified integration class for Mailcow + KumoMTA"""
    
    def __init__(self, mailcow_config: MailcowConfig, kumomta_config: KumoMTAConfig):
        self.mailcow_config = mailcow_config
        self.kumomta_config = kumomta_config
        self.session = requests.Session()
        
        # Configure session
        self.session.headers.update({
            'User-Agent': 'SmarterOutbound-Django/1.0',
            'Content-Type': 'application/json'
        })
    
    def _mailcow_request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make request to Mailcow API"""
        url = f"{self.mailcow_config.base_url}/api/v1/{endpoint}"
        headers = {'X-API-Key': self.mailcow_config.api_key}
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                headers=headers,
                json=data,
                verify=self.mailcow_config.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Mailcow API error: {e}")
            raise
    
    def _kumomta_request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make request to KumoMTA API"""
        url = f"{self.kumomta_config.base_url}/{endpoint}"
        headers = {}
        
        if self.kumomta_config.api_key:
            headers['Authorization'] = f'Bearer {self.kumomta_config.api_key}'
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                headers=headers,
                json=data,
                verify=self.kumomta_config.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"KumoMTA API error: {e}")
            raise
    
    # Mailcow User Management
    def create_mailbox(self, username: str, password: str, domain: str, **kwargs) -> Dict:
        """Create a new mailbox in Mailcow"""
        data = {
            'username': username,
            'password': password,
            'domain': domain,
            'active': '1',
            **kwargs
        }
        return self._mailcow_request('POST', 'add/mailbox', data)
    
    def get_mailbox(self, username: str) -> Dict:
        """Get mailbox details"""
        return self._mailcow_request('GET', f'get/mailbox/{username}')
    
    def update_mailbox(self, username: str, **kwargs) -> Dict:
        """Update mailbox details"""
        data = {'items': [username], 'attr': kwargs}
        return self._mailcow_request('POST', 'edit/mailbox', data)
    
    def delete_mailbox(self, username: str) -> Dict:
        """Delete a mailbox"""
        return self._mailcow_request('POST', 'delete/mailbox', {'items': [username]})
    
    # Mailcow Domain Management
    def create_domain(self, domain: str, **kwargs) -> Dict:
        """Create a new domain in Mailcow"""
        data = {'domain': domain, 'active': '1', **kwargs}
        return self._mailcow_request('POST', 'add/domain', data)
    
    def get_domains(self) -> List[Dict]:
        """Get all domains"""
        return self._mailcow_request('GET', 'get/domain/all')
    
    def update_domain(self, domain: str, **kwargs) -> Dict:
        """Update domain settings"""
        data = {'items': [domain], 'attr': kwargs}
        return self._mailcow_request('POST', 'edit/domain', data)
    
    # KumoMTA Integration
    def get_kumomta_status(self) -> Dict:
        """Get KumoMTA service status"""
        return self._kumomta_request('GET', 'health')
    
    def get_kumomta_metrics(self) -> Dict:
        """Get KumoMTA performance metrics"""
        return self._kumomta_request('GET', 'metrics')
    
    def get_delivery_stats(self) -> Dict:
        """Get email delivery statistics"""
        return self._kumomta_request('GET', 'stats/delivery')
    
    # Unified Operations
    def setup_user_for_cold_email(self, username: str, password: str, domain: str) -> Dict:
        """Complete setup for a user to use cold email services"""
        try:
            # 1. Create mailbox in Mailcow
            mailbox_result = self.create_mailbox(username, password, domain)
            logger.info(f"Created mailbox: {username}")
            
            # 2. Get SMTP credentials
            mailbox_info = self.get_mailbox(username)
            
            # 3. Return unified credentials
            return {
                'success': True,
                'mailbox_id': mailbox_result.get('msg', [''])[0],
                'smtp_host': f"mail.{domain}",
                'smtp_port': 587,
                'smtp_username': username,
                'smtp_password': password,
                'imap_host': f"mail.{domain}",
                'imap_port': 993,
                'imap_username': username,
                'imap_password': password,
                'kumomta_relay': f"kumod-enterprise:25"
            }
            
        except Exception as e:
            logger.error(f"Failed to setup user {username}: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_system_health(self) -> Dict:
        """Get overall system health status"""
        try:
            mailcow_health = self._mailcow_request('GET', 'get/domain/all')
            kumomta_health = self.get_kumomta_status()
            
            return {
                'mailcow': {
                    'status': 'healthy' if mailcow_health else 'unhealthy',
                    'domains_count': len(mailcow_health) if mailcow_health else 0
                },
                'kumomta': {
                    'status': kumomta_health.get('status', 'unknown'),
                    'uptime': kumomta_health.get('uptime', 'unknown')
                },
                'overall': 'healthy' if (mailcow_health and kumomta_health) else 'unhealthy',
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                'overall': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }

# Django settings integration
def get_integration_from_django_settings():
    """Get integration instance from Django environment variables"""
    mailcow_config = MailcowConfig(
        base_url=os.getenv('MAILCOW_BASE_URL', 'https://mail.smarteroutbound.com'),
        api_key=os.getenv('MAILCOW_API_KEY', ''),
        verify_ssl=os.getenv('MAILCOW_VERIFY_SSL', 'true').lower() == 'true'
    )
    
    kumomta_config = KumoMTAConfig(
        base_url=os.getenv('KUMOMTA_BASE_URL', 'http://localhost:8000'),
        api_key=os.getenv('KUMOMTA_API_KEY'),
        verify_ssl=os.getenv('KUMOMTA_VERIFY_SSL', 'false').lower() == 'true'
    )
    
    return MailcowKumoIntegration(mailcow_config, kumomta_config)

# Example usage
if __name__ == "__main__":
    # Test the integration
    integration = get_integration_from_django_settings()
    
    # Check system health
    health = integration.get_system_health()
    print(f"System Health: {json.dumps(health, indent=2)}")
    
    # Test mailbox creation (commented out for safety)
    # result = integration.setup_user_for_cold_email(
    #     username="test@example.com",
    #     password="securepassword123",
    #     domain="example.com"
    # )
    # print(f"User Setup: {json.dumps(result, indent=2)}")

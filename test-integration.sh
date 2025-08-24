#!/bin/bash
set -e

echo "🧪 Testing Mailcow + KumoMTA Integration"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_kumomta() {
    echo -e "\n${YELLOW}Testing KumoMTA...${NC}"
    
    # Check if KumoMTA is running
    if docker ps | grep -q "kumod-enterprise"; then
        echo -e "✅ KumoMTA container is running"
    else
        echo -e "❌ KumoMTA container is not running"
        return 1
    fi
    
    # Check KumoMTA health
    if curl -s http://localhost:8000/health > /dev/null; then
        echo -e "✅ KumoMTA health endpoint is accessible"
    else
        echo -e "❌ KumoMTA health endpoint is not accessible"
        return 1
    fi
    
    # Check if network exists
    if docker network ls | grep -q "kumo-network"; then
        echo -e "✅ KumoMTA network exists"
    else
        echo -e "❌ KumoMTA network does not exist"
        return 1
    fi
}

test_mailcow() {
    echo -e "\n${YELLOW}Testing Mailcow...${NC}"
    
    # Check if Mailcow is running
    if docker ps | grep -q "postfix-mailcow"; then
        echo -e "✅ Mailcow Postfix container is running"
    else
        echo -e "❌ Mailcow Postfix container is not running"
        return 1
    fi
    
    # Check relay configuration
    RELAYHOST=$(docker exec postfix-mailcow postconf -h relayhost 2>/dev/null || echo "ERROR")
    if [[ "$RELAYHOST" == "kumod-enterprise:25" ]]; then
        echo -e "✅ Postfix is configured to relay through KumoMTA"
    else
        echo -e "❌ Postfix relay configuration is incorrect: $RELAYHOST"
        return 1
    fi
    
    # Check network connectivity
    if docker exec postfix-mailcow ping -c 1 kumod-enterprise > /dev/null 2>&1; then
        echo -e "✅ Mailcow can reach KumoMTA"
    else
        echo -e "❌ Mailcow cannot reach KumoMTA"
        return 1
    fi
}

test_api() {
    echo -e "\n${YELLOW}Testing API Endpoints...${NC}"
    
    # Test KumoMTA API
    if curl -s http://localhost:8000/health | grep -q "status"; then
        echo -e "✅ KumoMTA API is responding"
    else
        echo -e "❌ KumoMTA API is not responding correctly"
        return 1
    fi
    
    # Test Mailcow API (if accessible)
    if [[ -n "$MAILCOW_API_KEY" ]]; then
        if curl -s -H "X-API-Key: $MAILCOW_API_KEY" \
                "https://mail.smarteroutbound.com/api/v1/get/domain/all" > /dev/null; then
            echo -e "✅ Mailcow API is accessible"
        else
            echo -e "⚠️  Mailcow API test failed (may be expected if not fully deployed)"
        fi
    else
        echo -e "⚠️  Skipping Mailcow API test (no API key set)"
    fi
}

test_email_flow() {
    echo -e "\n${YELLOW}Testing Email Flow...${NC}"
    
    # Check if KumoMTA is listening on port 25
    if netstat -tlnp 2>/dev/null | grep -q ":25 "; then
        echo -e "✅ KumoMTA is listening on port 25"
    else
        echo -e "❌ KumoMTA is not listening on port 25"
        return 1
    fi
    
    # Check if Mailcow is listening on port 587
    if netstat -tlnp 2>/dev/null | grep -q ":587 "; then
        echo -e "✅ Mailcow is listening on port 587"
    else
        echo -e "❌ Mailcow is not listening on port 587"
        return 1
    fi
}

test_django_integration() {
    echo -e "\n${YELLOW}Testing Django Integration...${NC}"
    
    # Check if Python script exists
    if [[ -f "django-integration.py" ]]; then
        echo -e "✅ Django integration script exists"
        
        # Test if script can run
        if python3 -c "import requests, json, os; print('✅ Dependencies available')" 2>/dev/null; then
            echo -e "✅ Python dependencies are available"
        else
            echo -e "❌ Python dependencies are missing"
            return 1
        fi
    else
        echo -e "❌ Django integration script not found"
        return 1
    fi
}

# Main test execution
main() {
    local exit_code=0
    
    echo "Starting integration tests..."
    
    # Run all tests
    test_kumomta || exit_code=1
    test_mailcow || exit_code=1
    test_api || exit_code=1
    test_email_flow || exit_code=1
    test_django_integration || exit_code=1
    
    echo -e "\n${YELLOW}Test Summary${NC}"
    echo "============"
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed! Integration is working correctly.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Configure your domain DNS records"
        echo "2. Set up SSL certificates"
        echo "3. Test email delivery through the system"
        echo "4. Integrate with your Django application"
    else
        echo -e "${RED}❌ Some tests failed. Please check the errors above.${NC}"
        echo ""
        echo "Common fixes:"
        echo "1. Ensure KumoMTA is running: cd ../kumomta-integration-new && docker-compose up -d"
        echo "2. Check Docker network: docker network ls | grep kumo"
        echo "3. Verify container health: docker-compose ps"
        echo "4. Check logs: docker logs kumod-enterprise"
    fi
    
    return $exit_code
}

# Check if we're in the right directory
if [[ ! -f "docker-compose.override.yml" ]]; then
    echo -e "${RED}❌ Please run this script from the mailcow-development directory${NC}"
    exit 1
fi

# Run tests
main "$@"

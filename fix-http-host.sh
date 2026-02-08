#!/bin/bash

# Quick Fix for HTTP_HOST Error
# Run this if you're experiencing "Undefined array key HTTP_HOST" errors

echo "=========================================="
echo "Quick Fix for HTTP_HOST Error"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}This will fix the HTTP_HOST error in your current deployment${NC}"
echo ""

# Fix 1: Set WordPress URL in wp-config.php
echo "Setting WordPress URL constants..."
docker compose exec wpcli wp config set WP_HOME "http://localhost:8080" --allow-root 2>/dev/null || \
docker compose exec -u 33:33 wpcli wp config set WP_HOME "http://localhost:8080" 2>/dev/null

docker compose exec wpcli wp config set WP_SITEURL "http://localhost:8080" --allow-root 2>/dev/null || \
docker compose exec -u 33:33 wpcli wp config set WP_SITEURL "http://localhost:8080" 2>/dev/null

# Fix 2: Create wp-cli.yml
echo "Creating wp-cli.yml configuration..."
docker compose exec wpcli bash -c 'cat > /var/www/html/wp-cli.yml << EOF
url: http://localhost:8080
allow-root: true
EOF'

# Fix 3: Update database options
echo "Updating database options..."
docker compose exec wpcli wp option update home "http://localhost:8080" --allow-root 2>/dev/null || \
docker compose exec -u 33:33 wpcli wp option update home "http://localhost:8080" 2>/dev/null

docker compose exec wpcli wp option update siteurl "http://localhost:8080" --allow-root 2>/dev/null || \
docker compose exec -u 33:33 wpcli wp option update siteurl "http://localhost:8080" 2>/dev/null

echo ""
echo -e "${GREEN}Fix applied!${NC}"
echo ""
echo "Now you can run the setup script:"
echo "  docker compose exec wpcli bash /setup.sh"
echo ""

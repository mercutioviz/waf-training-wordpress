#!/bin/bash
# Reset the training environment

set -e

echo "WAF Training Environment Reset"
echo "=============================="
echo ""
echo "WARNING: This will delete all data and reset the environment!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Reset cancelled."
    exit 0
fi

echo ""
echo "Stopping containers..."
docker-compose down

echo ""
echo "Removing volumes..."
docker volume rm waf-training-wordpress_wordpress_data waf-training-wordpress_db_data 2>/dev/null || true

echo ""
echo "Cleaning up..."
rm -rf wordpress-data/ mysql-data/ 2>/dev/null || true

echo ""
echo "Rebuilding and starting..."
docker-compose up -d

echo ""
echo "Reset complete! Monitoring setup progress..."
echo ""
docker-compose logs -f setup

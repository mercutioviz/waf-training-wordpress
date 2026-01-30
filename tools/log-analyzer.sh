#!/bin/bash
# Simple log analyzer for WAF training

echo "WAF Training - Log Analyzer"
echo "============================"
echo ""

# Check if container is running
if ! docker ps | grep -q "waf-training-wordpress"; then
    echo "Error: WordPress container is not running"
    exit 1
fi

echo "Recent WordPress errors:"
echo "------------------------"
docker exec waf-training-wordpress tail -n 50 /var/www/html/wp-content/debug.log 2>/dev/null || echo "No debug log found (debugging may be disabled)"

echo ""
echo "Recent Apache access log (last 20 requests):"
echo "---------------------------------------------"
docker exec waf-training-wordpress tail -n 20 /var/log/apache2/access.log 2>/dev/null || echo "No access log found"

echo ""
echo "Recent Apache error log:"
echo "------------------------"
docker exec waf-training-wordpress tail -n 20 /var/log/apache2/error.log 2>/dev/null || echo "No error log found"

echo ""
echo "Database connection status:"
echo "---------------------------"
docker exec waf-training-db mysqladmin -u wordpress -pwordpress_password_change_me status 2>/dev/null || echo "Cannot connect to database"

echo ""
echo "Recent MySQL errors:"
echo "--------------------"
docker exec waf-training-db tail -n 20 /var/log/mysql/error.log 2>/dev/null || echo "No MySQL error log found"

echo ""
echo "Container status:"
echo "-----------------"
docker-compose ps

echo ""
echo "Container resource usage:"
echo "-------------------------"
docker stats --no-stream waf-training-wordpress waf-training-db

echo ""
echo "For real-time logs, use:"
echo "  docker-compose logs -f wordpress"
echo "  docker-compose logs -f db"

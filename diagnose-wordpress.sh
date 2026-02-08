#!/bin/bash

# WordPress Installation Diagnostic Script
# This script checks all components to diagnose why WordPress isn't installing

echo "=========================================="
echo "WordPress Installation Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Check 1: Container Status
print_check "Checking container status..."
echo ""
docker compose ps
echo ""

# Check 2: Database Connection
print_check "Testing database connection from WordPress container..."
DB_TEST=$(docker compose exec wordpress bash -c 'php -r "
\$conn = mysqli_connect(\"db\", \"wordpress\", \"wordpress_pass\", \"wordpress\");
if (\$conn) {
    echo \"SUCCESS\";
    mysqli_close(\$conn);
} else {
    echo \"FAILED: \" . mysqli_connect_error();
}"' 2>&1)

if [[ "$DB_TEST" == *"SUCCESS"* ]]; then
    print_pass "Database connection successful"
else
    print_fail "Database connection failed: $DB_TEST"
fi
echo ""

# Check 3: WordPress Files
print_check "Checking WordPress core files..."
WP_EXISTS=$(docker compose exec wordpress test -f /var/www/html/wp-config.php && echo "EXISTS" || echo "MISSING")
if [ "$WP_EXISTS" = "EXISTS" ]; then
    print_pass "wp-config.php exists"
else
    print_fail "wp-config.php is missing"
fi

WP_INDEX=$(docker compose exec wordpress test -f /var/www/html/index.php && echo "EXISTS" || echo "MISSING")
if [ "$WP_INDEX" = "EXISTS" ]; then
    print_pass "index.php exists"
else
    print_fail "index.php is missing"
fi
echo ""

# Check 4: Database Tables
print_check "Checking WordPress database tables..."
TABLES=$(docker compose exec db mysql -u wordpress -pwordpress_pass wordpress -e "SHOW TABLES;" 2>/dev/null | grep -c "wp_")
if [ "$TABLES" -gt 0 ]; then
    print_pass "Found $TABLES WordPress tables"
else
    print_fail "No WordPress tables found - WordPress not installed"
fi
echo ""

# Check 5: WordPress Installation Status
print_check "Checking WordPress installation status..."
WP_INSTALLED=$(docker compose exec wpcli wp core is-installed --allow-root 2>&1 && echo "INSTALLED" || echo "NOT_INSTALLED")
if [ "$WP_INSTALLED" = "INSTALLED" ]; then
    print_pass "WordPress is installed"
else
    print_fail "WordPress is NOT installed"
    print_info "This is the root cause - WordPress core installation hasn't completed"
fi
echo ""

# Check 6: WordPress accessibility via HTTP
print_check "Testing WordPress HTTP access..."
HTTP_CODE=$(docker compose exec wordpress curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    print_pass "WordPress responding via HTTP (code: $HTTP_CODE)"
elif [ "$HTTP_CODE" = "500" ]; then
    print_fail "WordPress returning 500 error - check PHP logs"
else
    print_info "WordPress HTTP response code: $HTTP_CODE"
fi
echo ""

# Check 7: nginx accessibility
print_check "Testing nginx access..."
NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null)
if [ "$NGINX_CODE" = "200" ] || [ "$NGINX_CODE" = "302" ]; then
    print_pass "nginx responding (code: $NGINX_CODE)"
else
    print_fail "nginx not responding properly (code: $NGINX_CODE)"
fi
echo ""

# Check 8: PHP-FPM Status
print_check "Checking PHP-FPM process..."
PHP_FPM=$(docker compose exec wordpress ps aux | grep php-fpm | grep -v grep | wc -l)
if [ "$PHP_FPM" -gt 0 ]; then
    print_pass "PHP-FPM is running ($PHP_FPM processes)"
else
    print_fail "PHP-FPM not running"
fi
echo ""

# Check 9: File Permissions
print_check "Checking file permissions..."
docker compose exec wordpress ls -ld /var/www/html
echo ""

# Check 10: Recent Logs
print_check "Recent WordPress container logs (last 20 lines)..."
docker compose logs --tail=20 wordpress
echo ""

print_check "Recent database logs (last 10 lines)..."
docker compose logs --tail=10 db
echo ""

# Summary and Recommendations
echo "=========================================="
echo "DIAGNOSTIC SUMMARY"
echo "=========================================="
echo ""

if [ "$WP_INSTALLED" = "NOT_INSTALLED" ]; then
    print_fail "ROOT CAUSE: WordPress is not installed"
    echo ""
    echo "RECOMMENDED FIXES:"
    echo ""
    echo "1. Manual WordPress Installation:"
    echo "   docker compose exec wpcli wp core install \\"
    echo "     --url='http://localhost:8080' \\"
    echo "     --title='TechGear Pro' \\"
    echo "     --admin_user='admin' \\"
    echo "     --admin_password='TechGear2024!' \\"
    echo "     --admin_email='admin@techgearpro.local' \\"
    echo "     --skip-email \\"
    echo "     --allow-root"
    echo ""
    echo "2. Check if wp-config.php has correct database credentials:"
    echo "   docker compose exec wordpress cat /var/www/html/wp-config.php | grep DB_"
    echo ""
    echo "3. Reset and reinstall:"
    echo "   docker compose down -v"
    echo "   docker compose up -d"
    echo "   # Wait 2 minutes for initialization"
    echo "   docker compose exec wpcli bash /setup.sh"
    echo ""
elif [ "$TABLES" -eq 0 ]; then
    print_fail "WordPress files exist but database is empty"
    echo ""
    echo "RECOMMENDED FIX:"
    echo "   docker compose exec wpcli wp db reset --yes --allow-root"
    echo "   docker compose exec wpcli wp core install \\"
    echo "     --url='http://localhost:8080' \\"
    echo "     --title='TechGear Pro' \\"
    echo "     --admin_user='admin' \\"
    echo "     --admin_password='TechGear2024!' \\"
    echo "     --admin_email='admin@techgearpro.local' \\"
    echo "     --skip-email \\"
    echo "     --allow-root"
    echo ""
else
    print_pass "All checks passed - WordPress should be working"
    echo ""
    echo "Try accessing: http://localhost:8080"
    echo "Admin panel: http://localhost:8080/wp-admin"
    echo "Username: admin"
    echo "Password: TechGear2024!"
fi

echo ""
echo "=========================================="

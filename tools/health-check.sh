#!/bin/bash
# Health check script for WAF Training WordPress environment

set -e

echo "WAF Training WordPress - Health Check"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Track overall status
ERRORS=0
WARNINGS=0

echo "Checking Docker environment..."
echo "------------------------------"

# Check if Docker is installed
if command -v docker &> /dev/null; then
    check_pass "Docker is installed"
    docker --version
else
    check_fail "Docker is not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check if Docker Compose is installed
if command -v docker-compose &> /dev/null; then
    check_pass "Docker Compose is installed"
    docker-compose --version
else
    check_fail "Docker Compose is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking containers..."
echo "----------------------"

# Check if containers are running
if docker ps | grep -q "waf-training-wordpress"; then
    check_pass "WordPress container is running"
else
    check_fail "WordPress container is not running"
    ERRORS=$((ERRORS + 1))
fi

if docker ps | grep -q "waf-training-db"; then
    check_pass "Database container is running"
else
    check_fail "Database container is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check setup container status
if docker ps -a | grep -q "waf-training-setup.*Exited (0)"; then
    check_pass "Setup container completed successfully"
elif docker ps -a | grep -q "waf-training-setup.*Exited"; then
    check_fail "Setup container exited with error"
    ERRORS=$((ERRORS + 1))
elif docker ps | grep -q "waf-training-setup"; then
    check_warn "Setup container is still running"
    WARNINGS=$((WARNINGS + 1))
else
    check_warn "Setup container not found (may not have run yet)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Checking services..."
echo "--------------------"

# Check if WordPress responds
if curl -sf http://localhost:8080 > /dev/null; then
    check_pass "WordPress is responding on port 8080"
else
    check_fail "WordPress is not responding on port 8080"
    ERRORS=$((ERRORS + 1))
fi

# Check WordPress admin
if curl -sf http://localhost:8080/wp-admin > /dev/null; then
    check_pass "WordPress admin is accessible"
else
    check_warn "WordPress admin returned an error (may be redirecting)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check WooCommerce shop
if curl -sf http://localhost:8080/shop > /dev/null; then
    check_pass "WooCommerce shop page is accessible"
else
    check_warn "WooCommerce shop page is not accessible"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Checking database..."
echo "--------------------"

# Check MySQL is responding
if docker exec waf-training-db mysqladmin ping -h localhost --silent 2>/dev/null; then
    check_pass "MySQL is responding"
else
    check_fail "MySQL is not responding"
    ERRORS=$((ERRORS + 1))
fi

# Check WordPress database exists
if docker exec waf-training-db mysql -u wordpress -pwordpress_password_change_me -e "USE wordpress;" 2>/dev/null; then
    check_pass "WordPress database exists"
else
    check_fail "WordPress database does not exist"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking WordPress installation..."
echo "----------------------------------"

# Check if WordPress is installed
if docker exec waf-training-wordpress wp --allow-root core is-installed 2>/dev/null; then
    check_pass "WordPress is installed"
else
    check_fail "WordPress is not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check WordPress version
WP_VERSION=$(docker exec waf-training-wordpress wp --allow-root core version 2>/dev/null || echo "unknown")
echo "WordPress version: $WP_VERSION"

# Check if WooCommerce is active
if docker exec waf-training-wordpress wp --allow-root plugin is-active woocommerce 2>/dev/null; then
    check_pass "WooCommerce plugin is active"
else
    check_warn "WooCommerce plugin is not active"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Checking data..."
echo "----------------"

# Count products
PRODUCT_COUNT=$(docker exec waf-training-wordpress wp --allow-root wc product list --format=count --user=1 2>/dev/null || echo "0")
if [ "$PRODUCT_COUNT" -gt 0 ]; then
    check_pass "Products exist: $PRODUCT_COUNT"
else
    check_warn "No products found"
    WARNINGS=$((WARNINGS + 1))
fi

# Count orders
ORDER_COUNT=$(docker exec waf-training-wordpress wp --allow-root wc order list --format=count --user=1 2>/dev/null || echo "0")
if [ "$ORDER_COUNT" -gt 0 ]; then
    check_pass "Orders exist: $ORDER_COUNT"
else
    check_warn "No orders found"
    WARNINGS=$((WARNINGS + 1))
fi

# Count users
USER_COUNT=$(docker exec waf-training-wordpress wp --allow-root user list --format=count 2>/dev/null || echo "0")
if [ "$USER_COUNT" -gt 1 ]; then
    check_pass "Users exist: $USER_COUNT"
else
    check_warn "Only admin user found"
    WARNINGS=$((WARNINGS + 1))
fi

# Count posts
POST_COUNT=$(docker exec waf-training-wordpress wp --allow-root post list --post_type=post --format=count 2>/dev/null || echo "0")
if [ "$POST_COUNT" -gt 0 ]; then
    check_pass "Blog posts exist: $POST_COUNT"
else
    check_warn "No blog posts found"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Checking volumes..."
echo "-------------------"

# Check if volumes exist
if docker volume ls | grep -q "waf-training-wordpress_wordpress_data"; then
    check_pass "WordPress data volume exists"
else
    check_fail "WordPress data volume does not exist"
    ERRORS=$((ERRORS + 1))
fi

if docker volume ls | grep -q "waf-training-wordpress_db_data"; then
    check_pass "Database data volume exists"
else
    check_fail "Database data volume does not exist"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking resources..."
echo "---------------------"

# Check disk space
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
echo "Available disk space: $DISK_AVAIL"

# Check Docker disk usage
echo "Docker disk usage:"
docker system df

echo ""
echo "Summary"
echo "-------"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo "Your WAF training environment is ready to use."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}All critical checks passed, but there are $WARNINGS warnings.${NC}"
    echo "The environment should work, but some optional features may be missing."
    exit 0
else
    echo -e "${RED}Health check failed with $ERRORS errors and $WARNINGS warnings.${NC}"
    echo "Please review the errors above and consult the troubleshooting guide."
    exit 1
fi

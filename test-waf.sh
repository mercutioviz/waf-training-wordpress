#!/bin/bash

# WAF Testing Script - TechGear Pro
# This script generates various request patterns to test WAF false positive detection
# Run this AFTER placing your WordPress site behind a WAF

# Configuration
# Accept target URL as first CLI argument, fall back to env var, then default
SITE_URL="${1:-${SITE_URL:-http://localhost:8080}}"
VERBOSE="${VERBOSE:-0}"

# Realistic browser User-Agent strings
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1"
)

# Select a random User-Agent for this session
pick_random_ua() {
    local count=${#USER_AGENTS[@]}
    local index=$((RANDOM % count))
    echo "${USER_AGENTS[$index]}"
}

UA_STRING="$(pick_random_ua)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to make request and check response
test_request() {
    local method=$1
    local url=$2
    local data=$3
    local description=$4
    
    print_test "$description"
    
    if [ "$VERBOSE" = "1" ]; then
        echo "  URL: $url"
        [ ! -z "$data" ] && echo "  Data: $data"
    fi
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" -A "$UA_STRING" "$url" 2>&1)
    else
        response=$(curl -s -w "\n%{http_code}" -A "$UA_STRING" -X "$method" -d "$data" "$url" 2>&1)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        print_pass "HTTP $http_code - Request succeeded"
        return 0
    elif [ "$http_code" = "403" ] || [ "$http_code" = "406" ]; then
        print_fail "HTTP $http_code - WAF BLOCKED (Potential False Positive)"
        return 1
    else
        print_info "HTTP $http_code - Unexpected response"
        return 2
    fi
}

echo "=========================================="
echo "TechGear Pro WAF Testing Script"
echo "=========================================="
echo ""
print_info "Testing site: $SITE_URL"
print_info "User-Agent: $UA_STRING"
print_info "Usage: $0 [TARGET_URL]  (default: http://localhost:8080)"
print_info "Set VERBOSE=1 for detailed output"
echo ""

# Counter for results
total_tests=0
passed=0
blocked=0
errors=0

# Test 1: Basic site access
echo -e "\n${YELLOW}=== Test Suite 1: Basic Access ===${NC}"
test_request "GET" "$SITE_URL/" "" "Homepage access"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/shop/" "" "Shop page access"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 2: Product searches with special characters (SQLi false positives)
echo -e "\n${YELLOW}=== Test Suite 2: Product Search (SQLi False Positives) ===${NC}"

test_request "GET" "$SITE_URL/?s=O%27Reilly" "" "Search: O'Reilly (apostrophe)"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/?s=15%22+MacBook" "" "Search: 15\" MacBook (quotes)"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/?s=USB-C+to+USB-A" "" "Search: USB-C to USB-A (hyphens)"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/?s=SELECT+*+FROM+products" "" "Search: SELECT * FROM products (SQL-like)"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/?s=price%3E100" "" "Search: price>100 (comparison operator)"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 3: Product filters (parameter injection false positives)
echo -e "\n${YELLOW}=== Test Suite 3: Product Filters ===${NC}"

test_request "GET" "$SITE_URL/shop/?min_price=50&max_price=200" "" "Price filter"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/shop/?orderby=price&order=asc" "" "Sort by price"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/shop/?product_cat=laptops" "" "Category filter"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 4: WordPress REST API (might trigger rate limiting)
echo -e "\n${YELLOW}=== Test Suite 4: REST API Access ===${NC}"

test_request "GET" "$SITE_URL/wp-json/wp/v2/posts" "" "Get posts via REST API"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/wp-json/wc/v3/products" "" "Get products via WooCommerce API"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 5: Path-based requests (path traversal false positives)
echo -e "\n${YELLOW}=== Test Suite 5: Static Resources ===${NC}"

test_request "GET" "$SITE_URL/wp-content/plugins/woocommerce/readme.txt" "" "Access plugin readme"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/wp-includes/js/jquery/jquery.min.js" "" "Access jQuery library"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 6: User registration (if enabled)
echo -e "\n${YELLOW}=== Test Suite 6: User Interaction ===${NC}"

test_request "GET" "$SITE_URL/my-account/" "" "Access customer account page"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/cart/" "" "Access shopping cart"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/checkout/" "" "Access checkout page"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 7: Common WordPress paths
echo -e "\n${YELLOW}=== Test Suite 7: WordPress Endpoints ===${NC}"

test_request "GET" "$SITE_URL/wp-login.php" "" "Access login page"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

test_request "GET" "$SITE_URL/xmlrpc.php" "" "Access XML-RPC (often blocked)"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

# Test 8: Header injection tests
echo -e "\n${YELLOW}=== Test Suite 8: Referer and User-Agent ===${NC}"

test_request "GET" "$SITE_URL/" "" "Request with normal User-Agent"
((total_tests++)); [ $? -eq 0 ] && ((passed++)) || [ $? -eq 1 ] && ((blocked++)) || ((errors++))

print_test "Request with suspicious User-Agent (sqlmap)"
suspicious_code=$(curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: sqlmap/1.0" "$SITE_URL/")
if [ "$suspicious_code" = "403" ] || [ "$suspicious_code" = "406" ]; then
    print_pass "HTTP $suspicious_code - Suspicious UA correctly blocked"
elif [ "$suspicious_code" = "200" ]; then
    print_info "HTTP $suspicious_code - Suspicious UA was allowed (WAF may not filter UAs)"
else
    print_info "HTTP $suspicious_code - Unexpected response"
fi
((total_tests++)); ((passed++))

# Test 9: Rate limiting (multiple rapid requests)
echo -e "\n${YELLOW}=== Test Suite 9: Rate Limiting ===${NC}"
print_test "Sending 10 rapid requests to test rate limiting"

rate_limit_blocked=0
for i in {1..10}; do
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -A "$UA_STRING" "$SITE_URL/")
    if [ "$http_code" = "429" ] || [ "$http_code" = "403" ]; then
        ((rate_limit_blocked++))
    fi
    sleep 0.1
done

if [ $rate_limit_blocked -gt 0 ]; then
    print_fail "$rate_limit_blocked/10 requests blocked by rate limiting"
else
    print_pass "All 10 rapid requests succeeded (no rate limiting triggered)"
fi
((total_tests++))
[ $rate_limit_blocked -eq 0 ] && ((passed++)) || ((blocked++))

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total Tests:    ${BLUE}$total_tests${NC}"
echo -e "Passed:         ${GREEN}$passed${NC}"
echo -e "Blocked (FP):   ${RED}$blocked${NC}"
echo -e "Errors:         ${YELLOW}$errors${NC}"
echo ""

if [ $blocked -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $blocked potential false positives!${NC}"
    echo "Review your WAF logs to tune rules for these legitimate requests."
elif [ $passed -eq $total_tests ]; then
    echo -e "${GREEN}✓ All tests passed! No false positives detected.${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests had unexpected results.${NC}"
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "1. Review your WAF logs for blocked requests"
echo "2. Identify which WAF rules triggered"
echo "3. Determine if blocks are false positives"
echo "4. Create exceptions or tune thresholds"
echo "5. Re-run this script to verify fixes"
echo "=========================================="

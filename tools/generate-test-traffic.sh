#!/bin/bash
# Generate test traffic to trigger WAF rules

SERVER="${1:-http://localhost:8080}"

echo "Generating test traffic to: $SERVER"
echo "===================================="
echo ""

# Function to make request and show status
test_request() {
    local name="$1"
    local cmd="$2"
    
    echo -n "Testing: $name ... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "✓ (200 OK)"
    else
        echo "✗ (Blocked or Error)"
    fi
}

echo "Normal traffic (should pass):"
echo "------------------------------"
test_request "Homepage" "curl -sf '$SERVER'"
test_request "Shop page" "curl -sf '$SERVER/shop'"
test_request "Blog page" "curl -sf '$SERVER/blog'"
test_request "Product page" "curl -sf '$SERVER/shop'"

echo ""
echo "Testing potential false positives:"
echo "----------------------------------"

# Long cookie
test_request "Long cookie header" "curl -sf -H 'Cookie: $(python3 -c \"print('x'*2000)\")' '$SERVER/wp-admin'"

# Many headers
HEADERS=""
for i in {1..30}; do
    HEADERS="$HEADERS -H 'X-Test-$i: value'"
done
test_request "Many headers (30)" "curl -sf $HEADERS '$SERVER/shop'"

# Many parameters
PARAMS="?"
for i in {1..60}; do
    PARAMS="${PARAMS}param${i}=value&"
done
test_request "Many parameters (60)" "curl -sf '$SERVER/shop${PARAMS}'"

# Long parameter value
test_request "Long parameter value" "curl -sf -X POST '$SERVER/wp-comments-post.php' -d 'comment=$(python3 -c \"print('x'*3000)\")'"

echo ""
echo "Testing attack patterns (should be blocked):"
echo "---------------------------------------------"

# SQL injection
test_request "SQL injection in URL" "curl -sf '$SERVER/shop?id=1%27%20OR%201=1--'"
test_request "SQL injection in POST" "curl -sf -X POST '$SERVER/wp-login.php' -d 'log=admin%27%20OR%201=1--&pwd=test'"

# XSS
test_request "XSS in parameter" "curl -sf '$SERVER/shop?search=<script>alert(1)</script>'"

# Path traversal
test_request "Path traversal" "curl -sf '$SERVER/../../../etc/passwd'"

# Command injection
test_request "Command injection" "curl -sf '$SERVER/shop?cmd=ls%20-la'"

echo ""
echo "Test traffic generation complete!"
echo "Check your WAF logs to see which requests were blocked."

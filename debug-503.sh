#!/bin/bash
# debug-503.sh — Diagnose 503 errors in the WordPress Docker stack
# Usage: bash debug-503.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}[PASS]${NC} $1"; }
fail()  { echo -e "  ${RED}[FAIL]${NC} $1"; }
info()  { echo -e "  ${YELLOW}[INFO]${NC} $1"; }
header(){ echo ""; echo -e "${CYAN}━━━ $1 ━━━${NC}"; }

ERRORS=0

# ─────────────────────────────────────────────
header "1. Container Status"
# ─────────────────────────────────────────────
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
echo ""

for c in techgear_nginx techgear_wordpress techgear_mysql; do
    STATE=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo "not_found")
    if [ "$STATE" = "running" ]; then
        pass "$c is running"
        # Check OOMKilled
        OOM=$(docker inspect -f '{{.State.OOMKilled}}' "$c" 2>/dev/null)
        [ "$OOM" = "true" ] && { fail "$c was OOM-killed!"; ERRORS=$((ERRORS + 1)); }
    else
        fail "$c state: $STATE"
        ERRORS=$((ERRORS + 1))
    fi
done

# ─────────────────────────────────────────────
header "2. HTTP Response Test (localhost:8080)"
# ─────────────────────────────────────────────
# Report the response time alongside the code. A slow-but-working site and a
# dead one both used to collapse into "000", which hid the real symptom: the
# previous --max-time of 10s was shorter than some legitimate responses here,
# so a working site was reported as refused.
HTTP_TIMEOUT=30
HTTP_OUT=$(curl -so /dev/null -w "%{http_code} %{time_total}" --max-time "$HTTP_TIMEOUT" http://localhost:8080/ 2>/dev/null || true)
HTTP_CODE=$(echo "$HTTP_OUT" | awk '{print $1}')
HTTP_TIME=$(echo "$HTTP_OUT" | awk '{print $2}')
[ -z "$HTTP_CODE" ] && HTTP_CODE="000"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    pass "HTTP $HTTP_CODE in ${HTTP_TIME}s — site is responding"
    # Anything past a couple of seconds for a local request is worth surfacing;
    # it usually means PHP is blocking on something (loopback request, external
    # API call from a plugin) rather than that the stack is broken.
    if [ -n "$HTTP_TIME" ] && [ "${HTTP_TIME%%.*}" -ge 3 ] 2>/dev/null; then
        info "Response took ${HTTP_TIME}s — slow for a local request; check section 9 and plugin loopback/outbound calls"
    fi
elif [ "$HTTP_CODE" = "503" ]; then
    fail "HTTP 503 — upstream (PHP-FPM) is unreachable from nginx"
    ERRORS=$((ERRORS + 1))
elif [ "$HTTP_CODE" = "502" ]; then
    fail "HTTP 502 — bad gateway, PHP-FPM may have crashed"
    ERRORS=$((ERRORS + 1))
elif [ "$HTTP_CODE" = "000" ]; then
    # Distinguish "nothing listening" from "took longer than the timeout".
    if curl -so /dev/null --connect-timeout 5 --max-time 5 http://localhost:8080/ 2>/dev/null; then
        fail "Request did not complete within ${HTTP_TIMEOUT}s"
    elif (echo > /dev/tcp/127.0.0.1/8080) 2>/dev/null; then
        fail "Port 8080 accepts connections but no response within ${HTTP_TIMEOUT}s — PHP is hanging, not nginx"
    else
        fail "Connection refused — nginx is not listening on 8080"
    fi
    ERRORS=$((ERRORS + 1))
else
    info "HTTP $HTTP_CODE in ${HTTP_TIME}s"
fi

# ─────────────────────────────────────────────
header "3. Nginx Error Log (last 20 lines)"
# ─────────────────────────────────────────────
docker exec techgear_nginx cat /var/log/nginx/wordpress-error.log 2>/dev/null | tail -20 || \
    docker exec techgear_nginx cat /var/log/nginx/error.log 2>/dev/null | tail -20 || \
    info "Could not read nginx error log"

# ─────────────────────────────────────────────
header "4. PHP-FPM Process Check (wordpress container)"
# ─────────────────────────────────────────────
# Use `docker top`, which inspects the container's processes from the host.
# The previous check ran `ps aux` *inside* the container, but the wordpress:fpm
# image ships no procps - so the count was always 0 and this always reported
# "PHP-FPM is NOT running" even while the site served traffic normally.
FPM_COUNT=$(docker top techgear_wordpress 2>/dev/null | grep -c "php-fpm" || true)
FPM_COUNT=$(echo "$FPM_COUNT" | tr -d '[:space:]')
[ -z "$FPM_COUNT" ] && FPM_COUNT=0

if [ "$FPM_COUNT" -gt 0 ] 2>/dev/null; then
    pass "PHP-FPM running ($FPM_COUNT processes: 1 master + $((FPM_COUNT - 1)) worker(s))"
else
    fail "PHP-FPM is NOT running inside techgear_wordpress"
    ERRORS=$((ERRORS + 1))
    info "Try: docker compose restart wordpress"
fi

# ─────────────────────────────────────────────
header "5. TCP Connectivity: nginx → wordpress:9000"
# ─────────────────────────────────────────────
# nginx:alpine ships busybox nc, which handles -z fine. The previous probe used
# bash's /dev/tcp, which busybox ash does not implement - so it always returned
# FAIL and this section reported the upstream unreachable even when it wasn't.
# A missing nc is reported as "cannot test", not as a failure.
if docker exec techgear_nginx nc -z -w3 wordpress 9000 >/dev/null 2>&1; then
    pass "nginx can reach wordpress:9000"
elif ! docker exec techgear_nginx sh -c 'command -v nc >/dev/null 2>&1'; then
    info "nc not available in the nginx image — cannot probe directly"
    # Fall back to confirming FPM is bound, from the host.
    if docker top techgear_wordpress 2>/dev/null | grep -q "php-fpm: master"; then
        info "PHP-FPM master is running; assume :9000 is bound"
    else
        fail "PHP-FPM master not running — :9000 cannot be bound"
        ERRORS=$((ERRORS + 1))
    fi
else
    fail "nginx CANNOT reach wordpress:9000"
    ERRORS=$((ERRORS + 1))
fi

# ─────────────────────────────────────────────
header "6. WordPress Container Logs (last 25 lines)"
# ─────────────────────────────────────────────
docker compose logs --tail=25 wordpress 2>&1 | tail -25

# ─────────────────────────────────────────────
header "7. MySQL Health Check"
# ─────────────────────────────────────────────
PING=$(docker exec techgear_mysql mysqladmin -u wordpress -pwordpress_pass ping 2>&1)
if echo "$PING" | grep -q "alive"; then
    pass "MySQL is alive"
else
    fail "MySQL ping failed: $PING"
    ERRORS=$((ERRORS + 1))
fi

# ─────────────────────────────────────────────
header "8. MySQL Container Logs (last 15 lines)"
# ─────────────────────────────────────────────
docker compose logs --tail=15 db 2>&1 | tail -15

# ─────────────────────────────────────────────
header "9. WordPress Debug Log"
# ─────────────────────────────────────────────
DEBUG_LOG=$(docker exec techgear_wordpress cat /var/www/html/wp-content/debug.log 2>/dev/null | tail -30)
if [ -n "$DEBUG_LOG" ]; then
    echo "$DEBUG_LOG"
else
    info "No debug.log found (or empty) — this is normal if WP_DEBUG_LOG is off or no errors have occurred"
fi

# ─────────────────────────────────────────────
header "10. wp-config.php Database Credentials"
# ─────────────────────────────────────────────
docker exec techgear_wordpress sh -c 'grep -E "DB_(NAME|USER|PASSWORD|HOST)" /var/www/html/wp-config.php 2>/dev/null | head -8' || \
    info "Could not read wp-config.php"

# ─────────────────────────────────────────────
header "11. Docker Resource Usage"
# ─────────────────────────────────────────────
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | \
    grep -E "(NAME|techgear)" || docker stats --no-stream

# ─────────────────────────────────────────────
header "12. Disk Space"
# ─────────────────────────────────────────────
df -h / | head -5
echo ""
DISK_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')
if [ "$DISK_PCT" -gt 90 ]; then
    fail "Disk usage at ${DISK_PCT}% — this could cause failures"
    ERRORS=$((ERRORS + 1))
else
    pass "Disk usage at ${DISK_PCT}%"
fi

# ─────────────────────────────────────────────
header "13. Docker Network — DNS Resolution"
# ─────────────────────────────────────────────
RESOLVE=$(docker exec techgear_nginx sh -c 'getent hosts wordpress 2>/dev/null || ping -c1 -W2 wordpress 2>/dev/null | head -1' 2>/dev/null || echo "")
if [ -n "$RESOLVE" ]; then
    pass "nginx can resolve 'wordpress' hostname"
    info "$RESOLVE"
else
    fail "nginx cannot resolve 'wordpress' — network issue"
    ERRORS=$((ERRORS + 1))
    info "Try: docker compose down && docker compose up -d"
fi

# ═════════════════════════════════════════════
echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}  DIAGNOSTIC SUMMARY${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

if [ "$ERRORS" -eq 0 ]; then
    pass "All checks passed — no obvious issues detected"
    echo ""
    info "If you're still seeing 503s intermittently, try:"
    echo "    docker compose restart wordpress nginx"
    echo "    # or full recreate:"
    echo "    docker compose down && docker compose up -d"
else
    fail "$ERRORS issue(s) detected"
    echo ""
    echo -e "${YELLOW}  Common fixes:${NC}"
    echo ""
    echo "  1. Restart the stack:"
    echo "     docker compose restart"
    echo ""
    echo "  2. Recreate containers (preserves data volumes):"
    echo "     docker compose down && docker compose up -d"
    echo ""
    echo "  3. Full reset (DESTROYS data):"
    echo "     docker compose down -v && docker compose up -d"
    echo "     # Then re-run setup:"
    echo "     docker compose exec wpcli bash /setup.sh"
    echo ""
    echo "  4. If PHP-FPM specifically is down:"
    echo "     docker compose restart wordpress"
    echo ""
    echo "  5. If MySQL is the issue:"
    echo "     docker compose restart db"
    echo "     sleep 15"
    echo "     docker compose restart wordpress"
fi

echo ""
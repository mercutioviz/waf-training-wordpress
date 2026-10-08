#!/bin/bash

# TLS Key Logging Control - TechGear Pro
#
# Enables/disables SSLKEYLOGFILE capture in the nginx container so TLS streams
# recorded with tcpdump can be decrypted in Wireshark.
#
# The site's TLS config uses ECDHE + TLS 1.3, so the server private key in
# certs/ CANNOT decrypt a capture - forward secrecy means a key log is the only
# way in.
#
# Usage:
#   ./setup-keylog.sh on       # enable, recreate nginx, print capture recipe
#   ./setup-keylog.sh off      # disable and recreate nginx
#   ./setup-keylog.sh status   # show current state and key count
#   ./setup-keylog.sh clear    # truncate the key log

set -euo pipefail

cd "$(dirname "$0")"

KEYLOG_DIR="./keylog"
KEYLOG_FILE="$KEYLOG_DIR/keys.log"
CONTAINER_KEYLOG="/keylog/keys.log"
ENV_FILE=".env"
NGINX_UID=101   # the 'nginx' user inside the image; workers drop to this

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_info()   { echo -e "${BLUE}ℹ${NC} $1"; }
print_warn()   { echo -e "${YELLOW}!${NC} $1"; }
print_error()  { echo -e "${RED}✗${NC} $1"; }

# This repo ships with docker-compose v1 on some hosts and the v2 plugin on
# others; pick whichever is present.
if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
else
    print_error "Neither 'docker compose' nor 'docker-compose' found"
    exit 1
fi

# Rewrite a KEY=VALUE pair in .env, creating the file if needed.
set_env_var() {
    local key="$1" value="$2"
    touch "$ENV_FILE"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

enable_keylog() {
    mkdir -p "$KEYLOG_DIR"
    touch "$KEYLOG_FILE"

    # Workers run as uid 101 and a bind mount keeps the HOST directory's
    # ownership, overriding what the Dockerfile set. Without this chown the
    # shim cannot open the file and it silently stays empty.
    if ! chown -R "${NGINX_UID}:${NGINX_UID}" "$KEYLOG_DIR" 2>/dev/null; then
        print_warn "Could not chown $KEYLOG_DIR (need sudo?) - falling back to world-writable"
        chmod 777 "$KEYLOG_DIR"
        chmod 666 "$KEYLOG_FILE"
    fi

    set_env_var "NGINX_LD_PRELOAD" "/usr/local/lib/libsslkeylog.so"
    set_env_var "SSLKEYLOGFILE" "$CONTAINER_KEYLOG"

    print_info "Rebuilding and recreating nginx..."
    $DC up -d --build nginx

    sleep 2
    print_status "TLS key logging ENABLED"
    print_info "Key log: $KEYLOG_FILE"
    echo ""
    print_warn "This logs keys for EVERY TLS session nginx serves."
    print_warn "Treat the file as sensitive as the private key. Lab use only."
    echo ""
    echo "─── Capture workflow ───────────────────────────────────────────"
    echo ""
    echo "1. Start tcpdump BEFORE making requests (a session whose handshake"
    echo "   is missing from the pcap cannot be decrypted):"
    echo ""
    echo "     sudo tcpdump -i any -s 0 -w capture.pcap 'tcp port 8443'"
    echo ""
    echo "2. Generate traffic:"
    echo ""
    echo "     ./test-waf.sh https://localhost:8443"
    echo ""
    echo "3. Stop tcpdump (Ctrl+C), then embed the secrets into the capture:"
    echo ""
    echo "     editcap --inject-secrets tls,$KEYLOG_FILE \\"
    echo "         capture.pcap capture-dsb.pcapng"
    echo ""
    echo "   Or point Wireshark at the key log directly:"
    echo "     Preferences → Protocols → TLS → (Pre)-Master-Secret log filename"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
}

disable_keylog() {
    set_env_var "NGINX_LD_PRELOAD" ""
    set_env_var "SSLKEYLOGFILE" ""

    print_info "Recreating nginx without key logging..."
    $DC up -d nginx

    print_status "TLS key logging DISABLED"
    if [ -s "$KEYLOG_FILE" ]; then
        print_warn "$KEYLOG_FILE still holds secrets - './setup-keylog.sh clear' to wipe"
    fi
}

show_status() {
    local preload=""
    if [ -f "$ENV_FILE" ]; then
        preload=$(grep "^NGINX_LD_PRELOAD=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)
    fi

    if [ -n "$preload" ]; then
        print_status "Key logging is ENABLED in $ENV_FILE"
    else
        print_info "Key logging is DISABLED"
    fi

    # What the running container actually has, which may differ from .env if
    # nginx has not been recreated since the last toggle.
    if docker ps --format '{{.Names}}' | grep -q '^techgear_nginx$'; then
        local running
        running=$(docker inspect techgear_nginx \
            --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
            | grep -E '^(LD_PRELOAD|SSLKEYLOGFILE)=' | grep -v '=$' || true)
        if [ -n "$running" ]; then
            print_status "Running container has key logging active:"
            echo "$running" | sed 's/^/    /'
        else
            print_info "Running container does NOT have key logging active"
        fi
    else
        print_warn "techgear_nginx is not running"
    fi

    if [ -f "$KEYLOG_FILE" ]; then
        local lines
        lines=$(wc -l < "$KEYLOG_FILE" | tr -d ' ')
        print_info "$KEYLOG_FILE holds $lines key line(s)"
    else
        print_info "No key log file yet"
    fi
}

clear_keylog() {
    if [ -f "$KEYLOG_FILE" ]; then
        : > "$KEYLOG_FILE"
        print_status "Key log cleared"
    else
        print_info "No key log file to clear"
    fi
}

case "${1:-}" in
    on|enable)   enable_keylog ;;
    off|disable) disable_keylog ;;
    status)      show_status ;;
    clear)       clear_keylog ;;
    *)
        echo "Usage: $0 {on|off|status|clear}"
        echo ""
        echo "  on      Enable TLS key logging and recreate nginx"
        echo "  off     Disable key logging and recreate nginx"
        echo "  status  Show whether key logging is active"
        echo "  clear   Truncate the key log file"
        exit 1
        ;;
esac

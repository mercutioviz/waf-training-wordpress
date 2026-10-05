#!/bin/bash

# Self-Signed Certificate Generation - TechGear Pro
#
# Creates the TLS keypair the nginx reverse proxy serves on :443 (published as
# 8443 on the host). Self-signed is fine here: this is a throwaway training lab,
# and a browser trust warning is itself a useful thing for analysts to see.
#
# Usage:
#   ./generate-certs.sh           # generate if missing, otherwise leave alone
#   ./generate-certs.sh --force   # regenerate even if certs already exist

set -euo pipefail

CERT_DIR="${CERT_DIR:-$(dirname "$0")/certs}"
CERT_NAME="techgear.local"
DAYS="${DAYS:-825}"

CRT_FILE="$CERT_DIR/$CERT_NAME.crt"
KEY_FILE="$CERT_DIR/$CERT_NAME.key"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_info()   { echo -e "${BLUE}ℹ${NC} $1"; }
print_warn()   { echo -e "${YELLOW}!${NC} $1"; }

FORCE=0
if [ "${1:-}" = "--force" ]; then
    FORCE=1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl not found - install it or generate the keypair elsewhere" >&2
    exit 1
fi

if [ -f "$CRT_FILE" ] && [ -f "$KEY_FILE" ] && [ "$FORCE" -eq 0 ]; then
    print_info "Certificate already exists at $CRT_FILE"
    print_info "Re-run with --force to regenerate"
    openssl x509 -in "$CRT_FILE" -noout -subject -enddate
    exit 0
fi

mkdir -p "$CERT_DIR"

print_info "Generating self-signed certificate for $CERT_NAME (valid $DAYS days)..."

# Modern clients ignore CN entirely, so the SAN list is what actually matters.
# localhost/127.0.0.1 are included so curl and test-waf.sh work from the Docker
# host without a /etc/hosts entry.
openssl req -x509 -nodes \
    -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CRT_FILE" \
    -days "$DAYS" \
    -subj "/C=US/ST=California/L=San Francisco/O=TechGear Pro/CN=$CERT_NAME" \
    -addext "subjectAltName=DNS:$CERT_NAME,DNS:localhost,IP:127.0.0.1" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
    -addext "extendedKeyUsage=serverAuth" \
    2>/dev/null

chmod 644 "$CRT_FILE"
chmod 600 "$KEY_FILE"

print_status "Certificate: $CRT_FILE"
print_status "Private key: $KEY_FILE"
echo ""
openssl x509 -in "$CRT_FILE" -noout -subject -enddate -ext subjectAltName
echo ""
print_warn "Self-signed - browsers will warn, and curl needs -k"
print_info "To reach the site as https://techgear.local:8443, add to your client's hosts file:"
print_info "  <docker-host-ip>  techgear.local"
echo ""
print_info "Then: docker compose up -d nginx"

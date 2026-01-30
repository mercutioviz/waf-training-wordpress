#!/bin/bash
# Wait for WordPress to be ready and perform initial installation

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Checking WordPress availability..."

# Wait for WordPress container to be ready
sleep 10

# Check if WordPress is already installed
if wp_cli core is-installed 2>/dev/null; then
    log_success "WordPress is already installed"
    exit 0
fi

log_info "Installing WordPress..."

# Install WordPress
wp_cli core install \
    --url="${WORDPRESS_SITE_URL}" \
    --title="${WORDPRESS_SITE_TITLE}" \
    --admin_user="${WORDPRESS_ADMIN_USER}" \
    --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
    --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
    --skip-email

log_success "WordPress installed successfully"

# Verify installation
if ! wp_cli core is-installed; then
    log_error "WordPress installation verification failed"
    exit 1
fi

log_info "WordPress version: $(wp_cli core version)"

exit 0

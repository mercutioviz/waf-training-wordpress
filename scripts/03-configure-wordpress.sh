#!/bin/bash
# Configure WordPress core settings

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Configuring WordPress settings..."

# Set site URL and tagline
set_option "siteurl" "${WORDPRESS_SITE_URL}"
set_option "home" "${WORDPRESS_SITE_URL}"
set_option "blogname" "${WORDPRESS_SITE_TITLE}"
set_option "blogdescription" "${WORDPRESS_SITE_TAGLINE}"

# Set permalink structure
log_info "Setting permalink structure..."
wp_cli rewrite structure '/%postname%/' --hard

# Set timezone
set_option "timezone_string" "America/Denver"

# Date and time formats
set_option "date_format" "F j, Y"
set_option "time_format" "g:i a"

# Registration settings
set_option "users_can_register" "1"
set_option "default_role" "customer"

# Discussion settings
set_option "default_comment_status" "open"
set_option "comment_registration" "0"
set_option "comment_moderation" "0"

# Media settings
set_option "thumbnail_size_w" "300"
set_option "thumbnail_size_h" "300"
set_option "medium_size_w" "768"
set_option "medium_size_h" "768"
set_option "large_size_w" "1024"
set_option "large_size_h" "1024"

# Reading settings
set_option "posts_per_page" "12"
set_option "show_on_front" "page"

# Install and activate theme
THEME_SLUG=$(cat /tmp/config/theme.txt | xargs)
log_info "Installing theme: ${THEME_SLUG}"

if ! wp_cli theme is-installed "${THEME_SLUG}"; then
    install_theme "${THEME_SLUG}"
fi

activate_theme "${THEME_SLUG}"

# Disable WordPress updates
set_option "auto_updater_disabled" "1"

log_success "WordPress configuration complete"

exit 0

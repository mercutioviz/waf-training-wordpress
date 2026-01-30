#!/bin/bash
# WP-CLI helper functions

# Source logging
source /tmp/scripts/utils/logging.sh

# WP-CLI wrapper with error handling
wp_cli() {
    log_debug "Running: wp $*"
    php -d memory_limit=2048M /usr/local/bin/wp "$@" --allow-root --path=/var/www/html 2>&1
    local exit_code=$?
    if [ ${exit_code} -ne 0 ]; then
        log_error "WP-CLI command failed: wp $*"
        return ${exit_code}
    fi
    return 0
}

# Wait for WordPress to be accessible
wait_for_wordpress() {
    local max_attempts=60
    local attempt=0
    
    log_info "Waiting for WordPress to be ready..."
    
    while [ ${attempt} -lt ${max_attempts} ]; do
        if wp_cli core is-installed 2>/dev/null; then
            log_success "WordPress is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_debug "Attempt ${attempt}/${max_attempts}..."
        sleep 2
    done
    
    log_error "WordPress did not become ready in time"
    return 1
}

# Check if plugin is installed
plugin_is_installed() {
    local plugin_slug=$1
    wp_cli plugin is-installed "${plugin_slug}" 2>/dev/null
    return $?
}

# Check if plugin is active
plugin_is_active() {
    local plugin_slug=$1
    wp_cli plugin is-active "${plugin_slug}" 2>/dev/null
    return $?
}

# Install and activate plugin with error handling
install_activate_plugin() {
    local plugin_slug=$1
    local plugin_name=${2:-${plugin_slug}}
    
    log_info "Installing plugin: ${plugin_name}"
    
    if plugin_is_installed "${plugin_slug}"; then
        log_debug "Plugin ${plugin_slug} already installed"
    else
        if ! wp_cli plugin install "${plugin_slug}" --activate; then
            log_error "Failed to install plugin: ${plugin_slug}"
            return 1
        fi
    fi
    
    if plugin_is_active "${plugin_slug}"; then
        log_debug "Plugin ${plugin_slug} already active"
    else
        if ! wp_cli plugin activate "${plugin_slug}"; then
            log_error "Failed to activate plugin: ${plugin_slug}"
            return 1
        fi
    fi
    
    log_success "Plugin installed and activated: ${plugin_name}"
    return 0
}

# Install theme
install_theme() {
    local theme_slug=$1
    local theme_name=${2:-${theme_slug}}
    
    log_info "Installing theme: ${theme_name}"
    
    if wp_cli theme is-installed "${theme_slug}" 2>/dev/null; then
        log_debug "Theme ${theme_slug} already installed"
    else
        if ! wp_cli theme install "${theme_slug}"; then
            log_error "Failed to install theme: ${theme_slug}"
            return 1
        fi
    fi
    
    log_success "Theme installed: ${theme_name}"
    return 0
}

# Activate theme
activate_theme() {
    local theme_slug=$1
    
    log_info "Activating theme: ${theme_slug}"
    
    if ! wp_cli theme activate "${theme_slug}"; then
        log_error "Failed to activate theme: ${theme_slug}"
        return 1
    fi
    
    log_success "Theme activated: ${theme_slug}"
    return 0
}

# Set WordPress option
set_option() {
    local option_name=$1
    local option_value=$2
    
    log_debug "Setting option: ${option_name} = ${option_value}"
    
    if ! wp_cli option update "${option_name}" "${option_value}"; then
        log_error "Failed to set option: ${option_name}"
        return 1
    fi
    
    return 0
}

# Get WordPress option
get_option() {
    local option_name=$1
    wp_cli option get "${option_name}" 2>/dev/null
    return $?
}

# Create user if not exists
create_user_if_not_exists() {
    local username=$1
    local email=$2
    local password=$3
    local role=${4:-subscriber}
    local display_name=${5:-${username}}
    
    if wp_cli user get "${username}" 2>/dev/null; then
        log_debug "User already exists: ${username}"
        return 0
    fi
    
    log_info "Creating user: ${username}"
    
    if ! wp_cli user create "${username}" "${email}" \
        --role="${role}" \
        --user_pass="${password}" \
        --display_name="${display_name}" \
        --first_name="${display_name%% *}" \
        --last_name="${display_name##* }"; then
        log_error "Failed to create user: ${username}"
        return 1
    fi
    
    log_success "User created: ${username}"
    return 0
}

# Create page if not exists
create_page_if_not_exists() {
    local page_title=$1
    local page_content=${2:-""}
    local page_status=${3:-publish}
    
    # Check if page exists
    local page_id=$(wp_cli post list --post_type=page --title="${page_title}" --field=ID --format=csv 2>/dev/null | head -n1)
    
    if [ -n "${page_id}" ]; then
        log_debug "Page already exists: ${page_title} (ID: ${page_id})"
        echo "${page_id}"
        return 0
    fi
    
    log_info "Creating page: ${page_title}"
    
    page_id=$(wp_cli post create \
        --post_type=page \
        --post_title="${page_title}" \
        --post_content="${page_content}" \
        --post_status="${page_status}" \
        --porcelain)
    
    if [ -z "${page_id}" ]; then
        log_error "Failed to create page: ${page_title}"
        return 1
    fi
    
    log_success "Page created: ${page_title} (ID: ${page_id})"
    echo "${page_id}"
    return 0
}

# Rewrite flush
flush_rewrite_rules() {
    log_info "Flushing rewrite rules..."
    wp_cli rewrite flush --hard
    log_success "Rewrite rules flushed"
}

# Clear all caches
clear_all_caches() {
    log_info "Clearing all caches..."
    wp_cli cache flush
    wp_cli transient delete --all
    log_success "All caches cleared"
}

# Export functions
export -f wp_cli
export -f wait_for_wordpress
export -f plugin_is_installed
export -f plugin_is_active
export -f install_activate_plugin
export -f install_theme
export -f activate_theme
export -f set_option
export -f get_option
export -f create_user_if_not_exists
export -f create_page_if_not_exists
export -f flush_rewrite_rules
export -f clear_all_caches

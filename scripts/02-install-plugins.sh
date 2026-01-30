#!/bin/bash
# Install and activate all required plugins

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Installing WordPress plugins..."

# Read plugins from config file
PLUGINS_FILE="/tmp/config/plugins.txt"

if [ ! -f "${PLUGINS_FILE}" ]; then
    log_error "Plugins file not found: ${PLUGINS_FILE}"
    exit 1
fi

# Count plugins (excluding comments and empty lines)
TOTAL_PLUGINS=$(grep -v '^\s*#' "${PLUGINS_FILE}" | grep -v '^\s*$' | wc -l)
CURRENT_PLUGIN=0

log_info "Found ${TOTAL_PLUGINS} plugins to install"

# Read and install each plugin
while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ "${line}" =~ ^\s*# ]] || [[ -z "${line}" ]]; then
        continue
    fi
    
    # Trim whitespace
    plugin_slug=$(echo "${line}" | xargs)
    
    if [ -z "${plugin_slug}" ]; then
        continue
    fi
    
    CURRENT_PLUGIN=$((CURRENT_PLUGIN + 1))
    
    show_progress ${CURRENT_PLUGIN} ${TOTAL_PLUGINS} "Installing plugins"
    
    # Install and activate plugin
    if ! install_activate_plugin "${plugin_slug}"; then
        log_warn "Could not install plugin: ${plugin_slug} (continuing anyway)"
    fi
    
done < "${PLUGINS_FILE}"

echo "" # New line after progress

log_success "Plugin installation complete"

# List installed plugins
log_info "Installed plugins:"
wp_cli plugin list --format=table

exit 0

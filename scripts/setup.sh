#!/bin/bash
# Main setup orchestrator script
# This script coordinates all setup steps

set -e

# Source utilities
source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_section "WAF Training WordPress Setup"

log_info "Starting setup process..."
log_info "Site URL: ${WORDPRESS_SITE_URL}"
log_info "Admin User: ${WORDPRESS_ADMIN_USER}"

# Check if AUTO_SETUP is enabled
if [ "${AUTO_SETUP}" != "true" ]; then
    log_warn "AUTO_SETUP is not enabled. Skipping setup."
    exit 0
fi

# Setup steps
STEPS=(
#    "01-wait-for-wordpress.sh"
#    "02-install-plugins.sh"
#    "03-configure-wordpress.sh"
#    "04-setup-woocommerce.sh"
#    "05-import-products.sh"
#    "06-import-content.sh"
#    "07-create-users.sh"
#    "08-generate-orders.sh"
#    "09-add-reviews.sh"
    "10-finalize.sh"
)

TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=0

for step_script in "${STEPS[@]}"; do
    CURRENT_STEP=$((CURRENT_STEP + 1))
    
    log_section "Step ${CURRENT_STEP}/${TOTAL_STEPS}: ${step_script}"
    
    if [ -f "/tmp/scripts/${step_script}" ]; then
        if bash "/tmp/scripts/${step_script}"; then
            log_success "Completed: ${step_script}"
        else
            log_error "Failed: ${step_script}"
            exit 1
        fi
    else
        log_error "Script not found: ${step_script}"
        exit 1
    fi
    
    echo ""
done

log_section "Setup Complete!"

log_success "WordPress site is ready for WAF training"
log_info "Site URL: ${WORDPRESS_SITE_URL}"
log_info "Admin Login: ${WORDPRESS_SITE_URL}/wp-admin"
log_info "Username: ${WORDPRESS_ADMIN_USER}"
log_info "Password: ${WORDPRESS_ADMIN_PASSWORD}"

echo ""
log_info "You can now configure your WAF to protect this site."
echo ""

exit 0

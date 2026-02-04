#!/bin/bash
# Configure WooCommerce settings

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Configuring WooCommerce..."

# Verify WooCommerce is installed
if ! plugin_is_active "woocommerce"; then
    log_error "WooCommerce is not active"
    exit 1
fi

log_info "WooCommerce version: $(wp_cli plugin get woocommerce --field=version)"

# Store address settings
log_info "Setting store address..."
set_option "woocommerce_store_address" "${STORE_ADDRESS}"
set_option "woocommerce_store_address_2" "${STORE_ADDRESS_2}"
set_option "woocommerce_store_city" "${STORE_CITY}"
set_option "woocommerce_default_country" "${STORE_COUNTRY}:${STORE_STATE}"
set_option "woocommerce_store_postcode" "${STORE_POSTCODE}"

# Currency settings
log_info "Setting currency..."
set_option "woocommerce_currency" "${STORE_CURRENCY}"
set_option "woocommerce_price_thousand_sep" ","
set_option "woocommerce_price_decimal_sep" "."
set_option "woocommerce_price_num_decimals" "2"

# General settings
set_option "woocommerce_enable_reviews" "yes"
set_option "woocommerce_review_rating_verification_required" "no"
set_option "woocommerce_enable_review_rating" "yes"
set_option "woocommerce_review_rating_required" "yes"

# Inventory settings
set_option "woocommerce_manage_stock" "yes"
set_option "woocommerce_hold_stock_minutes" "60"
set_option "woocommerce_notify_low_stock" "yes"
set_option "woocommerce_notify_no_stock" "yes"

# Checkout settings
set_option "woocommerce_enable_guest_checkout" "yes"
set_option "woocommerce_enable_checkout_login_reminder" "yes"
set_option "woocommerce_enable_signup_and_login_from_checkout" "yes"

# Product settings
set_option "woocommerce_weight_unit" "lbs"
set_option "woocommerce_dimension_unit" "in"

# Disable tracking and marketplace suggestions
set_option "woocommerce_allow_tracking" "no"
set_option "woocommerce_show_marketplace_suggestions" "no"

# Mark onboarding as complete
set_option "woocommerce_task_list_complete" "yes"
set_option "woocommerce_onboarding_profile" '{"completed": true}'

# Create WooCommerce pages
log_info "Creating WooCommerce pages..."
wp_cli wc tool run install_pages --user="${WORDPRESS_ADMIN_USER}"

# Get page IDs
SHOP_PAGE_ID=$(wp_cli post list --post_type=page --name=shop --field=ID --format=csv 2>/dev/null | head -n1)
CART_PAGE_ID=$(wp_cli post list --post_type=page --name=cart --field=ID --format=csv 2>/dev/null | head -n1)
CHECKOUT_PAGE_ID=$(wp_cli post list --post_type=page --name=checkout --field=ID --format=csv 2>/dev/null | head -n1)
MYACCOUNT_PAGE_ID=$(wp_cli post list --post_type=page --name=my-account --field=ID --format=csv 2>/dev/null | head -n1)

log_info "Shop Page ID: ${SHOP_PAGE_ID}"
log_info "Cart Page ID: ${CART_PAGE_ID}"
log_info "Checkout Page ID: ${CHECKOUT_PAGE_ID}"
log_info "My Account Page ID: ${MYACCOUNT_PAGE_ID}"

# Configure payment gateways
log_info "Configuring payment gateways..."

# Enable direct bank transfer
wp_cli option update woocommerce_bacs_settings '{"enabled":"yes","title":"Direct Bank Transfer","description":"Make your payment directly into our bank account."}' --format=json

# Enable check payments
wp_cli option update woocommerce_cheque_settings '{"enabled":"yes","title":"Check Payments","description":"Please send a check to our office."}' --format=json

# Enable cash on delivery
wp_cli option update woocommerce_cod_settings '{"enabled":"yes","title":"Cash on Delivery","description":"Pay with cash upon delivery."}' --format=json

# Configure Stripe (test mode) if plugin is active
if plugin_is_active "woocommerce-gateway-stripe"; then
    log_info "Configuring Stripe payment gateway (test mode)..."
    wp_cli option update woocommerce_stripe_settings '{"enabled":"yes","title":"Credit Card (Stripe)","testmode":"yes","test_publishable_key":"pk_test_dummy_key","test_secret_key":"sk_test_dummy_key"}' --format=json
fi

# Configure shipping zones
log_info "Configuring shipping zones..."
log_info "Shipping zones can be configured manually via WooCommerce > Settings > Shipping"
log_info "Skipping automated shipping zone setup for training environment"

# Flush rewrite rules
flush_rewrite_rules

log_success "WooCommerce configuration complete"

exit 0

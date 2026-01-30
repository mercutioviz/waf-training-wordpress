#!/bin/bash
# Create user accounts (customers, shop managers, etc.)

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Creating user accounts..."

# Create shop manager
log_info "Creating shop manager account..."
create_user_if_not_exists \
    "shop.manager" \
    "shop.manager@summitoutfitters.com" \
    "ShopMgr#2024" \
    "shop_manager" \
    "Sarah Johnson"

# Create customer accounts
log_info "Creating customer accounts..."

declare -a CUSTOMERS=(
    "john.doe:john.doe@email.com:Customer1!:John Doe"
    "jane.smith:jane.smith@email.com:Customer2!:Jane Smith"
    "mike.wilson:mike.wilson@email.com:Customer3!:Mike Wilson"
    "emily.brown:emily.brown@email.com:Customer4!:Emily Brown"
    "david.jones:david.jones@email.com:Customer5!:David Jones"
    "sarah.davis:sarah.davis@email.com:Customer6!:Sarah Davis"
    "chris.miller:chris.miller@email.com:Customer7!:Chris Miller"
    "amanda.taylor:amanda.taylor@email.com:Customer8!:Amanda Taylor"
    "robert.anderson:robert.anderson@email.com:Customer9!:Robert Anderson"
    "lisa.thomas:lisa.thomas@email.com:Customer10!:Lisa Thomas"
    "james.jackson:james.jackson@email.com:Customer11!:James Jackson"
    "jennifer.white:jennifer.white@email.com:Customer12!:Jennifer White"
    "kevin.harris:kevin.harris@email.com:Customer13!:Kevin Harris"
    "michelle.martin:michelle.martin@email.com:Customer14!:Michelle Martin"
    "daniel.thompson:daniel.thompson@email.com:Customer15!:Daniel Thompson"
)

CREATED=0
TOTAL=${#CUSTOMERS[@]}

for customer_data in "${CUSTOMERS[@]}"; do
    IFS=':' read -r username email password display_name <<< "${customer_data}"
    
    CREATED=$((CREATED + 1))
    show_progress ${CREATED} ${TOTAL} "Creating customer accounts"
    
    create_user_if_not_exists "${username}" "${email}" "${password}" "customer" "${display_name}"
    
    # Add billing and shipping addresses for some customers
    if [ $((RANDOM % 2)) -eq 0 ]; then
        USER_ID=$(wp_cli user get "${username}" --field=ID 2>/dev/null)
        
        # Billing address
        wp_cli user meta update ${USER_ID} billing_first_name "${display_name%% *}" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_last_name "${display_name##* }" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_address_1 "$((RANDOM % 9999 + 1)) Main St" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_city "Denver" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_state "CO" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_postcode "$((RANDOM % 89999 + 80000))" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_country "US" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_email "${email}" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} billing_phone "303-555-$(printf '%04d' $((RANDOM % 10000)))" 2>/dev/null || true
        
        # Copy to shipping
        wp_cli user meta update ${USER_ID} shipping_first_name "${display_name%% *}" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} shipping_last_name "${display_name##* }" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} shipping_address_1 "$((RANDOM % 9999 + 1)) Main St" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} shipping_city "Denver" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} shipping_state "CO" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} shipping_postcode "$((RANDOM % 89999 + 80000))" 2>/dev/null || true
        wp_cli user meta update ${USER_ID} shipping_country "US" 2>/dev/null || true
    fi
done

echo "" # New line after progress

log_success "User account creation complete"

# Display user counts by role
log_info "User statistics:"
wp_cli user list --role=administrator --format=count | xargs -I {} log_info "Administrators: {}"
wp_cli user list --role=shop_manager --format=count | xargs -I {} log_info "Shop Managers: {}"
wp_cli user list --role=customer --format=count | xargs -I {} log_info "Customers: {}"

exit 0

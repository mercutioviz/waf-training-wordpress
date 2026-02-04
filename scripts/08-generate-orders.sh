#!/bin/bash
# Generate sample orders for the store

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Generating sample orders..."

# Check if order generation is enabled
if [ "${GENERATE_SAMPLE_ORDERS}" != "true" ]; then
    log_warn "Sample order generation is disabled. Skipping."
    exit 0
fi

# Get list of product IDs
PRODUCT_IDS=($(wp_cli wc product list --format=ids --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null))

if [ ${#PRODUCT_IDS[@]} -eq 0 ]; then
    log_warn "No products found. Cannot generate orders."
    exit 0
fi

log_info "Found ${#PRODUCT_IDS[@]} products"

# Get list of customer IDs
CUSTOMER_IDS=($(wp_cli user list --role=customer --field=ID 2>/dev/null))

if [ ${#CUSTOMER_IDS[@]} -eq 0 ]; then
    log_warn "No customers found. Cannot generate orders."
    exit 0
fi

log_info "Found ${#CUSTOMER_IDS[@]} customers"

# Order statuses to use
ORDER_STATUSES=("completed" "completed" "completed" "completed" "processing" "on-hold" "cancelled")

# Generate orders
NUM_ORDERS=${NUM_ORDERS:-75}
log_info "Generating ${NUM_ORDERS} orders..."

for i in $(seq 1 ${NUM_ORDERS}); do
    show_progress ${i} ${NUM_ORDERS} "Creating orders"
    
    # Select random customer
    CUSTOMER_ID=${CUSTOMER_IDS[$((RANDOM % ${#CUSTOMER_IDS[@]}))]}
    
    # Select random status (weighted toward completed)
    ORDER_STATUS=${ORDER_STATUSES[$((RANDOM % ${#ORDER_STATUSES[@]}))]}
    
    # Generate random date in the past (last 6 months)
    DAYS_AGO=$((RANDOM % 180 + 1))
    ORDER_DATE=$(date -d "${DAYS_AGO} days ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
    
    # Create order
    ORDER_ID=$(wp_cli wc order create \
        --customer_id=${CUSTOMER_ID} \
        --status=${ORDER_STATUS} \
        --user="${WORDPRESS_ADMIN_USER}" \
        --porcelain 2>/dev/null) || continue
    
    if [ -z "${ORDER_ID}" ]; then
        log_debug "Failed to create order ${i}"
        continue
    fi
    
    # Add random number of products (1-5) to order
    NUM_ITEMS=$((RANDOM % 5 + 1))
    
    for j in $(seq 1 ${NUM_ITEMS}); do
        # Select random product
        PRODUCT_ID=${PRODUCT_IDS[$((RANDOM % ${#PRODUCT_IDS[@]}))]}
        
        # Random quantity (usually 1, sometimes 2-3)
        if [ $((RANDOM % 10)) -lt 8 ]; then
            QUANTITY=1
        else
            QUANTITY=$((RANDOM % 3 + 1))
        fi
        
        # Add item to order
        wp_cli wc order_item create ${ORDER_ID} \
            --type=line_item \
            --product_id=${PRODUCT_ID} \
            --quantity=${QUANTITY} \
            --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || true
    done
    
    # Recalculate order totals
    wp_cli wc order update ${ORDER_ID} --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || true
    
    # Update order date
    wp_cli post update ${ORDER_ID} --post_date="${ORDER_DATE}" 2>/dev/null || true
    
    log_debug "Created order ${ORDER_ID} for customer ${CUSTOMER_ID}"
done

echo "" # New line after progress

log_success "Order generation complete"

# Display order statistics
log_info "Order statistics:"
for status in "completed" "processing" "on-hold" "cancelled"; do
    COUNT=$(wp_cli wc order list --status=${status} --format=count --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || echo "0")
    log_info "  ${status}: ${COUNT}"
done

TOTAL_ORDERS=$(wp_cli wc order list --format=count --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || echo "0")
log_info "Total orders: ${TOTAL_ORDERS}"

exit 0

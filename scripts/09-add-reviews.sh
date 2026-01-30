#!/bin/bash
# Add product reviews

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Adding product reviews..."

# Get list of published products
PRODUCT_IDS=($(wp_cli wc product list --status=publish --format=ids --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null))

if [ ${#PRODUCT_IDS[@]} -eq 0 ]; then
    log_warn "No products found. Cannot add reviews."
    exit 0
fi

log_info "Found ${#PRODUCT_IDS[@]} products"

# Get list of customer IDs for review authors
CUSTOMER_IDS=($(wp_cli user list --role=customer --field=ID 2>/dev/null))

if [ ${#CUSTOMER_IDS[@]} -eq 0 ]; then
    log_warn "No customers found. Using admin for reviews."
    CUSTOMER_IDS=(1)
fi

# Sample review content (positive bias for realism)
declare -a REVIEW_TEMPLATES=(
    "Great product! Exactly what I needed for my hiking trips. Quality is excellent and it arrived quickly.|5"
    "Very satisfied with this purchase. Good quality and fair price. Would recommend to others.|5"
    "Excellent gear! Used it on a week-long backpacking trip and it performed flawlessly.|5"
    "Good product overall. Works as advertised. Shipping was fast.|4"
    "Nice quality and well-made. Happy with my purchase.|4"
    "Solid product for the price. Does what it's supposed to do.|4"
    "Pretty good. A few minor issues but nothing major. Overall satisfied.|4"
    "Works well but sizing runs a bit large. Consider ordering a size down.|3"
    "Decent product but not quite what I expected. Still usable though.|3"
    "It's okay. Does the job but there are probably better options out there.|3"
    "Absolutely love this! Best outdoor gear purchase I've made this year. Highly recommended!|5"
    "Used this on my Colorado Trail hike. Held up great in all conditions. Super impressed.|5"
    "Outstanding quality and attention to detail. Worth every penny.|5"
    "Good value for money. Works as expected and seems durable.|4"
    "Happy with this purchase. Delivery was quick and product matches description.|4"
    "Really well made and functional. Took it on several hikes without any issues.|5"
    "Perfect for my needs. Great quality and fast shipping.|5"
    "Comfortable and durable. Used it extensively and it's holding up well.|5"
    "Good product but the price is a bit high compared to similar items.|4"
    "Works great! No complaints whatsoever. Would buy again.|5"
)

# Number of reviews to add
NUM_REVIEWS=${NUM_REVIEWS:-40}

# Randomly select products to review (not all products will have reviews)
PRODUCTS_TO_REVIEW=()
for i in $(seq 1 ${NUM_REVIEWS}); do
    PRODUCT_ID=${PRODUCT_IDS[$((RANDOM % ${#PRODUCT_IDS[@]}))]}
    PRODUCTS_TO_REVIEW+=("${PRODUCT_ID}")
done

log_info "Adding ${NUM_REVIEWS} reviews..."

CREATED=0

for PRODUCT_ID in "${PRODUCTS_TO_REVIEW[@]}"; do
    CREATED=$((CREATED + 1))
    show_progress ${CREATED} ${NUM_REVIEWS} "Adding reviews"
    
    # Select random review template
    REVIEW_DATA=${REVIEW_TEMPLATES[$((RANDOM % ${#REVIEW_TEMPLATES[@]}))]}
    IFS='|' read -r REVIEW_CONTENT RATING <<< "${REVIEW_DATA}"
    
    # Select random customer
    CUSTOMER_ID=${CUSTOMER_IDS[$((RANDOM % ${#CUSTOMER_IDS[@]}))]}
    
    # Get customer info
    CUSTOMER_EMAIL=$(wp_cli user get ${CUSTOMER_ID} --field=user_email 2>/dev/null)
    CUSTOMER_NAME=$(wp_cli user get ${CUSTOMER_ID} --field=display_name 2>/dev/null)
    
    # Random date in the past (last 120 days)
    DAYS_AGO=$((RANDOM % 120 + 1))
    REVIEW_DATE=$(date -d "${DAYS_AGO} days ago" '+%Y-%m-%d %H:%M:%S')
    
    # Create comment (review)
    COMMENT_ID=$(wp_cli comment create \
        --comment_post_ID=${PRODUCT_ID} \
        --comment_content="${REVIEW_CONTENT}" \
        --comment_author="${CUSTOMER_NAME}" \
        --comment_author_email="${CUSTOMER_EMAIL}" \
        --comment_date="${REVIEW_DATE}" \
        --comment_approved=1 \
        --user_id=${CUSTOMER_ID} \
        --porcelain 2>/dev/null)
    
    if [ -n "${COMMENT_ID}" ]; then
        # Add rating meta
        wp_cli comment meta add ${COMMENT_ID} rating ${RATING} 2>/dev/null || true
        wp_cli comment meta add ${COMMENT_ID} verified 1 2>/dev/null || true
        
        log_debug "Added review for product ${PRODUCT_ID} (Rating: ${RATING})"
    fi
done

echo "" # New line after progress

log_success "Review addition complete"

# Display review statistics
TOTAL_REVIEWS=$(wp_cli comment count --type=comment 2>/dev/null | grep -oP 'approved=\K\d+' || echo "0")
log_info "Total reviews: ${TOTAL_REVIEWS}"

exit 0

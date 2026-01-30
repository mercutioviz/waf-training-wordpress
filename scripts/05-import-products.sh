#!/bin/bash
# Import products into WooCommerce

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Importing products..."

# Create product categories
log_info "Creating product categories..."

CATEGORIES=(
    "Hiking:hiking"
    "Camping:camping"
    "Climbing:climbing"
    "Backpacking:backpacking"
    "Apparel:apparel"
    "Footwear:footwear"
    "Accessories:accessories"
)

for category_data in "${CATEGORIES[@]}"; do
    IFS=':' read -r cat_name cat_slug <<< "${category_data}"
    
    if ! wp_cli wc product_cat list --slug="${cat_slug}" --format=count --user="${WORDPRESS_ADMIN_USER}" | grep -q "^1$"; then
        log_info "Creating category: ${cat_name}"
        wp_cli wc product_cat create \
            --name="${cat_name}" \
            --slug="${cat_slug}" \
            --user="${WORDPRESS_ADMIN_USER}"
    else
        log_debug "Category already exists: ${cat_name}"
    fi
done

# Import sample products from WooCommerce
log_info "Importing WooCommerce sample products..."

if wp_cli plugin is-installed woocommerce; then
    # Check if sample products already imported
    PRODUCT_COUNT=$(wp_cli wc product list --format=count --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || echo "0")
    
    if [ "${PRODUCT_COUNT}" -lt "5" ]; then
        # Install WooCommerce sample data if available
        SAMPLE_DATA="/var/www/html/wp-content/plugins/woocommerce/sample-data/sample_products.csv"
        
        if [ -f "${SAMPLE_DATA}" ]; then
            log_info "Importing from: ${SAMPLE_DATA}"
            wp_cli wc product import "${SAMPLE_DATA}" --user="${WORDPRESS_ADMIN_USER}" || log_warn "Could not import sample CSV"
        fi
    fi
fi

# Create additional custom products
log_info "Creating custom products..."

# Array of realistic outdoor products
declare -a PRODUCTS=(
    "TrailBlazer Hiking Boots|89.99|footwear|Durable waterproof hiking boots with ankle support. Perfect for long trails and rugged terrain. Features Vibram sole and breathable Gore-Tex lining."
    "Alpine Summit Backpack 65L|149.99|backpacking|Large capacity backpack with adjustable suspension system. Multiple compartments, hydration compatible, and rain cover included."
    "Mountain Explorer Tent 2P|249.99|camping|Two-person four-season tent with aluminum poles. Waterproof rainfly, vestibule storage, and easy setup design."
    "All-Weather Sleeping Bag|119.99|camping|3-season mummy sleeping bag rated to 20°F. Synthetic insulation, compression sack included. Water-resistant shell."
    "Trekking Poles Carbon Fiber|79.99|hiking|Lightweight adjustable trekking poles. Cork grips, shock absorption, and tungsten carbide tips. Collapsible design."
    "Technical Climbing Harness|89.99|climbing|Adjustable climbing harness with 4 gear loops. Padded waist and legs for comfort. CE and UIAA certified."
    "Quick-Dry Hiking Shirt|44.99|apparel|Moisture-wicking technical shirt with UPF 50+ sun protection. Breathable mesh panels and zippered chest pocket."
    "Convertible Hiking Pants|69.99|apparel|Zip-off pants that convert to shorts. Multiple pockets, water-resistant, and stretchy fabric for mobility."
    "Insulated Water Bottle 32oz|34.99|accessories|Vacuum-insulated stainless steel bottle. Keeps drinks cold 24hrs or hot 12hrs. Wide mouth for ice cubes."
    "Portable Camp Stove|59.99|camping|Compact propane stove with windscreen. Adjustable flame control, piezo ignition, and carrying case included."
    "Headlamp 500 Lumens|39.99|accessories|Rechargeable LED headlamp with multiple modes. Red light mode, tilting head, and IPX4 water resistance."
    "Navigation Compass Professional|29.99|accessories|Precision orienteering compass with adjustable declination. Magnifying lens and clinometer included."
    "Emergency Survival Kit|49.99|camping|Comprehensive survival kit with first aid supplies, fire starter, emergency blanket, and multi-tool."
    "Waterproof Dry Bag 20L|24.99|accessories|Roll-top dry bag with shoulder strap. Perfect for kayaking, camping, and beach trips. IPX6 rated."
    "Camp Chair Lightweight|44.99|camping|Portable folding chair supporting 300lbs. Aluminum frame, breathable mesh, and compact carry bag."
    "Down Jacket 700 Fill|179.99|apparel|Lightweight packable down jacket. Water-resistant shell, zippered pockets, and stuff sack included."
    "Trail Running Shoes|109.99|footwear|Breathable trail runners with aggressive tread. Rock plate protection and quick-drying upper mesh."
    "Climbing Rope 60m|189.99|climbing|Dynamic climbing rope 10.2mm diameter. Dry treated, middle mark, and meets UIAA standards."
    "Bear Canister|79.99|backpacking|Bear-resistant food storage container. IGBC approved, 7-day capacity, and easy-open lid design."
    "Solar Panel Charger|69.99|accessories|Portable solar charger with USB ports. Foldable design, weather-resistant, and charges phones and tablets."
)

# Create products with variations for some items
CREATED=0
TOTAL=${#PRODUCTS[@]}

for product_data in "${PRODUCTS[@]}"; do
    IFS='|' read -r prod_name prod_price prod_cat prod_desc <<< "${product_data}"
    
    CREATED=$((CREATED + 1))
    show_progress ${CREATED} ${TOTAL} "Creating products"
    
    # Check if product already exists
    if wp_cli wc product list --search="${prod_name}" --format=count --user="${WORDPRESS_ADMIN_USER}" | grep -q "^0$"; then
        
        # Get category ID
        CAT_ID=$(wp_cli wc product_cat list --slug="${prod_cat}" --field=id --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null | head -n1)
        
        # Create product
        PRODUCT_ID=$(wp_cli wc product create \
            --name="${prod_name}" \
            --type=simple \
            --regular_price="${prod_price}" \
            --description="${prod_desc}" \
            --short_description="${prod_desc%%.*}." \
            --categories="[{\"id\":${CAT_ID}}]" \
            --status=publish \
            --catalog_visibility=visible \
            --manage_stock=true \
            --stock_quantity=$((RANDOM % 50 + 10)) \
            --user="${WORDPRESS_ADMIN_USER}" \
            --porcelain)
        
        log_debug "Created product: ${prod_name} (ID: ${PRODUCT_ID})"
    fi
done

echo "" # New line after progress

# Create some variable products (products with size/color options)
log_info "Creating variable products..."

# Example: Hiking socks with size variations
SOCK_PRODUCT_ID=$(wp_cli wc product create \
    --name="Merino Wool Hiking Socks" \
    --type=variable \
    --description="Premium merino wool hiking socks with cushioned sole and moisture-wicking properties." \
    --short_description="Premium merino wool hiking socks." \
    --status=publish \
    --user="${WORDPRESS_ADMIN_USER}" \
    --porcelain)

# Create size attribute
wp_cli wc product_attribute create \
    --name="Size" \
    --slug="size" \
    --type="select" \
    --order_by="menu_order" \
    --has_archives=true \
    --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || true

# Add variations
for size in "Small" "Medium" "Large" "X-Large"; do
    wp_cli wc product_variation create ${SOCK_PRODUCT_ID} \
        --regular_price="19.99" \
        --attributes="[{\"name\":\"Size\",\"option\":\"${size}\"}]" \
        --manage_stock=true \
        --stock_quantity=$((RANDOM % 30 + 10)) \
        --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || true
done

log_success "Product import complete"

# Display product count
FINAL_COUNT=$(wp_cli wc product list --format=count --user="${WORDPRESS_ADMIN_USER}")
log_info "Total products: ${FINAL_COUNT}"

exit 0

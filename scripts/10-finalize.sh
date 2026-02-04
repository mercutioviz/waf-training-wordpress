#!/bin/bash
# Finalize setup and cleanup

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Finalizing setup..."

# Create homepage
log_info "Setting up homepage..."

HOMEPAGE_CONTENT='<!-- wp:heading {"level":1} -->
<h1>Welcome to Summit Outfitters</h1>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Your premier destination for quality outdoor gear and adventure equipment.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons">
<div class="wp-block-button"><a class="wp-block-button__link" href="/shop">Shop Now</a></div>
<div class="wp-block-button"><a class="wp-block-button__link" href="/blog">Read Our Blog</a></div>
</div>
<!-- /wp:buttons -->

<!-- wp:heading -->
<h2>Featured Products</h2>
<!-- /wp:heading -->

<!-- wp:woocommerce/product-new {"columns":4,"rows":1} /-->

<!-- wp:heading -->
<h2>Latest from Our Blog</h2>
<!-- /wp:heading -->

<!-- wp:latest-posts {"postsToShow":3,"displayPostDate":true,"displayFeaturedImage":true} /-->'

# Check if homepage exists
HOME_PAGE_ID=$(wp_cli post list --post_type=page --name=home --field=ID --format=csv 2>/dev/null | head -n1)

if [ -z "${HOME_PAGE_ID}" ]; then
    HOME_PAGE_ID=$(create_page_if_not_exists "Home" "${HOMEPAGE_CONTENT}" "publish")
fi

# Set as homepage
set_option "page_on_front" "${HOME_PAGE_ID}"
set_option "show_on_front" "page"

# Create blog page
BLOG_PAGE_ID=$(wp_cli post list --post_type=page --name=blog --field=ID --format=csv 2>/dev/null | head -n1)

if [ -z "${BLOG_PAGE_ID}" ]; then
    BLOG_PAGE_ID=$(create_page_if_not_exists "Blog" "" "publish")
fi

set_option "page_for_posts" "${BLOG_PAGE_ID}"

# Create navigation menu
log_info "Creating navigation menu..."

# Check if menu exists
MENU_ID=$(wp_cli menu list --format=csv --fields=term_id,name 2>/dev/null | grep "Main Menu" | cut -d',' -f1 || echo "")

if [ -z "${MENU_ID}" ]; then
    MENU_ID=$(wp_cli menu create "Main Menu" --porcelain 2>/dev/null)
    log_info "Created menu: Main Menu (ID: ${MENU_ID})"
fi

# Add menu items
wp_cli menu item add-post ${MENU_ID} ${HOME_PAGE_ID} --title="Home" 2>/dev/null || true

SHOP_PAGE_ID=$(wp_cli post list --post_type=page --name=shop --field=ID --format=csv 2>/dev/null | head -n1)
if [ -n "${SHOP_PAGE_ID}" ]; then
    wp_cli menu item add-post ${MENU_ID} ${SHOP_PAGE_ID} --title="Shop" 2>/dev/null || true
fi

wp_cli menu item add-post ${MENU_ID} ${BLOG_PAGE_ID} --title="Blog" 2>/dev/null || true

ABOUT_PAGE_ID=$(wp_cli post list --post_type=page --name=about-us --field=ID --format=csv 2>/dev/null | head -n1)
if [ -n "${ABOUT_PAGE_ID}" ]; then
    wp_cli menu item add-post ${MENU_ID} ${ABOUT_PAGE_ID} --title="About" 2>/dev/null || true
fi

CONTACT_PAGE_ID=$(wp_cli post list --post_type=page --name=contact --field=ID --format=csv 2>/dev/null | head -n1)
if [ -n "${CONTACT_PAGE_ID}" ]; then
    wp_cli menu item add-post ${MENU_ID} ${CONTACT_PAGE_ID} --title="Contact" 2>/dev/null || true
fi

# Assign menu to primary location
wp_cli menu location assign ${MENU_ID} primary 2>/dev/null || true
wp_cli menu location assign ${MENU_ID} menu-1 2>/dev/null || true

# Set up Contact Form 7
log_info "Configuring Contact Form 7..."

# Check if default contact form exists, if not create one
CF7_EXISTS=$(wp_cli post list --post_type=wpcf7_contact_form --format=count 2>/dev/null || echo "0")

if [ "${CF7_EXISTS}" -eq "0" ]; then
    log_info "Creating default contact form..."
    
    FORM_CONTENT='<label> Your Name (required)
    [text* your-name] </label>

<label> Your Email (required)
    [email* your-email] </label>

<label> Subject
    [text your-subject] </label>

<label> Your Message
    [textarea your-message] </label>

[submit "Send"]'

    MAIL_TEMPLATE='Subject: [your-subject]
From: [your-name] <[your-email]>
Reply-To: [your-email]

[your-message]'

    wp_cli post create \
        --post_type=wpcf7_contact_form \
        --post_title="Contact form 1" \
        --post_status=publish \
        --post_content="${FORM_CONTENT}" 2>/dev/null || true
fi

# Update WooCommerce permalinks
# Update WooCommerce permalinks
log_info "Skipping WooCommerce permalinks (can be configured in admin if needed)..."

# Regenerate thumbnails for products
log_info "Regenerating product thumbnails..."
wp_cli media regenerate --yes 2>/dev/null || log_warn "Could not regenerate thumbnails"

# Clear all caches
log_info "Clearing caches..."
clear_all_caches

# Flush rewrite rules
log_info "Flushing rewrite rules..."
flush_rewrite_rules

# Deactivate and remove setup-only plugins
log_info "Cleaning up temporary plugins..."

# List of plugins to remove after setup
TEMP_PLUGINS=("fakerpress" "woocommerce-smooth-generator")

for plugin in "${TEMP_PLUGINS[@]}"; do
    if plugin_is_installed "${plugin}"; then
        if plugin_is_active "${plugin}"; then
            wp_cli plugin deactivate "${plugin}" 2>/dev/null || true
        fi
        wp_cli plugin delete "${plugin}" 2>/dev/null || true
        log_debug "Removed temporary plugin: ${plugin}"
    fi
done

# Optimize database
log_info "Optimizing database..."
wp_cli db optimize 2>/dev/null || log_warn "Could not optimize database"

# Create a setup completion marker
wp_cli option add waf_training_setup_complete "$(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || \
wp_cli option update waf_training_setup_complete "$(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null

# Generate a site summary
log_info "Site Summary:"
log_info "  Products: $(wp_cli wc product list --format=count --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || echo "0")"
log_info "  Orders: $(wp_cli wc order list --format=count --user="${WORDPRESS_ADMIN_USER}" 2>/dev/null || echo "0")"
log_info "  Customers: $(wp_cli user list --role=customer --format=count 2>/dev/null || echo "0")"
log_info "  Posts: $(wp_cli post list --post_type=post --format=count 2>/dev/null || echo "0")"
log_info "  Pages: $(wp_cli post list --post_type=page --format=count 2>/dev/null || echo "0")"
log_info "  Comments/Reviews: $(wp_cli comment count --type=comment 2>/dev/null | grep -oP 'approved=\K\d+' || echo "0")"

log_success "Finalization complete!"

exit 0

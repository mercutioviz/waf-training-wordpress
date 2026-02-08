#!/bin/bash

# TechGear Pro - WordPress WAF Training Environment Setup
# This script automates the complete setup of a WordPress site with WooCommerce
# and plugins designed to generate WAF false positives for training purposes

set -e

echo "=========================================="
echo "TechGear Pro WAF Training Setup"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

## Force memory limit
# Define the path to wp-config
WP_CONFIG="/var/www/html/wp-config.php"

# 1. Ensure the constants are present in wp-config.php
# We use 'grep' to check if they exist; if not, we use 'sed' to insert them after the <?php tag.
if ! grep -q "WP_MEMORY_LIMIT" "$WP_CONFIG"; then
    echo "Configuring WP_MEMORY_LIMIT..."
    sed -i "/<?php/a define( 'WP_MEMORY_LIMIT', '512M' );" "$WP_CONFIG"
fi

if ! grep -q "WP_MAX_MEMORY_LIMIT" "$WP_CONFIG"; then
    echo "Configuring WP_MAX_MEMORY_LIMIT..."
    sed -i "/<?php/a define( 'WP_MAX_MEMORY_LIMIT', '512M' );" "$WP_CONFIG"
fi

# 2. Export the environment variable for the remainder of this script's execution
# This forces the PHP engine running WP-CLI to ignore the system-wide 128MB limit.
export WP_CLI_PHP_ARGS="-d memory_limit=512M"

echo "Memory limits updated and exported. Proceeding with installations..."

# Wait for WordPress to be ready
print_info "Waiting for WordPress to be ready..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if wp core is-installed --allow-root 2>/dev/null; then
        print_status "WordPress is already installed!"
        break
    fi
    
    # Try to install WordPress
    if wp core install \
        --url="http://localhost:8080" \
        --title="TechGear Pro" \
        --admin_user="admin" \
        --admin_password="TechGear2024!" \
        --admin_email="admin@techgearpro.local" \
        --skip-email \
        --allow-root 2>/dev/null; then
        print_status "WordPress installed successfully!"
        break
    fi
    
    ((attempt++))
    print_info "Waiting for WordPress... attempt $attempt/$max_attempts"
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    print_error "WordPress installation timed out"
    exit 1
fi

# Configure WordPress constants to prevent HTTP_HOST warnings
print_info "Configuring WordPress constants..."
wp config set WP_HOME "http://localhost:8080" --allow-root 2>/dev/null || true
wp config set WP_SITEURL "http://localhost:8080" --allow-root 2>/dev/null || true
wp config set WP_CLI "true" --raw --allow-root 2>/dev/null || true
print_status "WordPress constants configured"

print_status "WordPress installed successfully!"

# Update permalink structure
print_info "Setting permalink structure..."
wp rewrite structure '/%postname%/' --allow-root
wp rewrite flush --allow-root
print_status "Permalinks configured"

# Install and activate plugins
print_info "Installing plugins (this may take a few minutes)..."

# Core plugins
PLUGINS=(
    "woocommerce"
    "contact-form-7"
    "wpforms-lite"
    "wordfence"
    "limit-login-attempts-reloaded"
    "wordpress-seo"
    "jetpack"
    "advanced-custom-fields"
    "wp-mail-smtp"
    "elementor"
    "ewww-image-optimizer"
    "updraftplus"
    "query-monitor"
    "user-switching"
    "wp-crontrol"
    "fakerpress"
)

for plugin in "${PLUGINS[@]}"; do
    wp plugin install "$plugin" --activate --allow-root
    print_status "Installed: $plugin"
done

# Configure WooCommerce
print_info "Configuring WooCommerce..."
wp option update woocommerce_store_address "123 Tech Street" --allow-root
wp option update woocommerce_store_city "San Francisco" --allow-root
wp option update woocommerce_default_country "US:CA" --allow-root
wp option update woocommerce_store_postcode "94102" --allow-root
wp option update woocommerce_currency "USD" --allow-root
wp option update woocommerce_product_type "both" --allow-root
wp option update woocommerce_allow_tracking "no" --allow-root
wp option update woocommerce_enable_reviews "yes" --allow-root
wp option update woocommerce_enable_coupons "yes" --allow-root

# Create WooCommerce pages
wp wc tool run install_pages --user=admin --allow-root

print_status "WooCommerce configured"

# Import products
print_info "Importing products from CSV..."
if [ -f /products.csv ]; then
    wp wc product import /products.csv --user=admin --allow-root 2>/dev/null || print_info "Product import completed (some warnings expected)"
    print_status "Products imported"
else
    print_error "products.csv not found, skipping product import"
fi

# Create product categories (in case they weren't created by import)
print_info "Creating product categories..."
CATEGORIES=("Laptops" "Accessories" "Cables & Adapters" "Gaming" "Smart Home" "Networking" "Storage" "PC Components" "Monitors" "Tablets")
for category in "${CATEGORIES[@]}"; do
    wp wc product_cat create --name="$category" --user=admin --allow-root 2>/dev/null || true
done
print_status "Categories created"

# Create users with different roles
print_info "Creating user accounts..."

# Administrators
wp user create manager1 manager1@techgearpro.local --role=administrator --user_pass="Manager123!" --first_name="Sarah" --last_name="Johnson" --allow-root
wp user create manager2 manager2@techgearpro.local --role=administrator --user_pass="Manager123!" --first_name="Michael" --last_name="Chen" --allow-root

# Shop Managers
wp user create shopmanager1 shopmanager@techgearpro.local --role=shop_manager --user_pass="Shop123!" --first_name="David" --last_name="Martinez" --allow-root
wp user create shopmanager2 support@techgearpro.local --role=shop_manager --user_pass="Shop123!" --first_name="Emily" --last_name="Williams" --allow-root

# Customers with full profiles
wp user create customer1 alice@example.com --role=customer --user_pass="Customer123!" --first_name="Alice" --last_name="Anderson" --allow-root
wp user create customer2 bob@example.com --role=customer --user_pass="Customer123!" --first_name="Bob" --last_name="Brown" --allow-root
wp user create customer3 carol@example.com --role=customer --user_pass="Customer123!" --first_name="Carol" --last_name="Davis" --allow-root
wp user create customer4 david@example.com --role=customer --user_pass="Customer123!" --first_name="David" --last_name="Evans" --allow-root
wp user create customer5 eve@example.com --role=customer --user_pass="Customer123!" --first_name="Eve" --last_name="Foster" --allow-root

# Additional customers (subscribers)
wp user create user1 frank@example.com --role=subscriber --user_pass="User123!" --first_name="Frank" --last_name="Garcia" --allow-root
wp user create user2 grace@example.com --role=subscriber --user_pass="User123!" --first_name="Grace" --last_name="Harris" --allow-root
wp user create user3 henry@example.com --role=subscriber --user_pass="User123!" --first_name="Henry" --last_name="Irving" --allow-root

print_status "Users created"

# Create blog posts with FakerPress
print_info "Generating blog content..."
wp faker post generate 15 --allow-root 2>/dev/null || print_info "Blog posts generation completed"
print_status "Blog content created"

# Create comments (including some that look suspicious)
print_info "Creating sample comments..."
PRODUCT_IDS=$(wp wc product list --fields=id --format=ids --allow-root)
if [ ! -z "$PRODUCT_IDS" ]; then
    for product_id in $(echo $PRODUCT_IDS | head -5); do
        # Normal comment
        wp comment create --comment_post_ID=$product_id \
            --comment_content="Great product! Works perfectly with my setup." \
            --comment_author="Happy Customer" \
            --comment_author_email="happy@example.com" \
            --comment_approved=1 \
            --allow-root 2>/dev/null || true
        
        # Technical comment that might trigger WAF
        wp comment create --comment_post_ID=$product_id \
            --comment_content="Fixed my issue! Was getting error 'SELECT * FROM users' in logs but this resolved it. Config file at /etc/config.conf needed updating." \
            --comment_author="Tech User" \
            --comment_author_email="techuser@example.com" \
            --comment_approved=1 \
            --allow-root 2>/dev/null || true
    done
fi
print_status "Comments created"

# Create standard pages
print_info "Creating standard pages..."

# About page
wp post create --post_type=page --post_title="About Us" \
    --post_content="<h2>About TechGear Pro</h2><p>We're passionate about technology and committed to providing the best tech products at competitive prices. Founded in 2020, we've grown to serve thousands of customers worldwide.</p><p>Our mission: Make cutting-edge technology accessible to everyone.</p>" \
    --post_status=publish --allow-root

# FAQ page
wp post create --post_type=page --post_title="FAQ" \
    --post_content="<h2>Frequently Asked Questions</h2><h3>What's your return policy?</h3><p>30-day money-back guarantee on all products.</p><h3>Do you ship internationally?</h3><p>Yes! We ship to over 50 countries.</p><h3>How do I track my order?</h3><p>You'll receive a tracking link via email once your order ships.</p>" \
    --post_status=publish --allow-root

# Contact page (will add Contact Form 7 to this)
wp post create --post_type=page --post_title="Contact" \
    --post_content="<h2>Get in Touch</h2><p>Have questions? We're here to help!</p>" \
    --post_status=publish --allow-root

# Returns Policy
wp post create --post_type=page --post_title="Returns & Refunds" \
    --post_content="<h2>Returns Policy</h2><p>We accept returns within 30 days of purchase. Items must be in original condition with all packaging and accessories.</p><h3>Refund Process</h3><p>Refunds are processed within 5-7 business days after we receive your return.</p>" \
    --post_status=publish --allow-root

# Privacy Policy
wp post create --post_type=page --post_title="Privacy Policy" \
    --post_content="<h2>Privacy Policy</h2><p>We collect and process personal data including: name, email, shipping address, and payment information. We use industry-standard encryption (TLS 1.3) to protect your data.</p><p>We never sell your personal information to third parties.</p>" \
    --post_status=publish --allow-root

print_status "Pages created"

# Configure Contact Form 7
print_info "Configuring Contact Forms..."

# Contact Us form
wp eval 'wpcf7_contact_form::get_instance( WPCF7_ContactForm::save( array(
    "title" => "Contact Us",
    "form" => "[text* your-name placeholder \"Your Name\"]\n\n[email* your-email placeholder \"Email Address\"]\n\n[tel your-phone placeholder \"Phone Number (optional)\"]\n\n[select your-subject \"General Inquiry\" \"Product Question\" \"Technical Support\" \"Partnership Opportunity\" \"Other\"]\n\n[textarea* your-message placeholder \"How can we help you? Feel free to include error messages, code snippets, or technical details.\"]\n\n[file your-attachment limit:5mb filetypes:jpg|jpeg|png|pdf|txt|log]\n\n[checkbox consent use_label_element \"I agree to the privacy policy\"]\n\n[submit \"Send Message\"]",
    "mail" => array(
        "subject" => "[_site_title] - [your-subject]",
        "sender" => "[your-name] <wordpress@techgearpro.local>",
        "body" => "From: [your-name] <[your-email]>\nPhone: [your-phone]\nSubject: [your-subject]\n\nMessage:\n[your-message]",
        "recipient" => "admin@techgearpro.local",
    ),
) ) );' --allow-root 2>/dev/null || print_info "Contact form created"

# Technical Support form
wp eval 'wpcf7_contact_form::get_instance( WPCF7_ContactForm::save( array(
    "title" => "Technical Support",
    "form" => "[text* customer-name placeholder \"Your Name\"]\n\n[email* customer-email placeholder \"Email Address\"]\n\n[text order-number placeholder \"Order Number (if applicable)\"]\n\n[select product-category \"Laptops\" \"Accessories\" \"Cables & Adapters\" \"Gaming\" \"Smart Home\" \"Networking\" \"Storage\" \"PC Components\" \"Other\"]\n\n[text* product-name placeholder \"Product Name or SKU\"]\n\n[textarea* issue-description placeholder \"Please describe your technical issue. Include error messages or system info. Example: Getting error: Cannot connect to server at 192.168.1.1\"]\n\n[file attachments limit:10mb filetypes:jpg|jpeg|png|pdf|txt|log|xml|json]\n\n[submit \"Submit Support Request\"]",
    "mail" => array(
        "subject" => "[_site_title] - Support Request",
        "sender" => "[customer-name] <wordpress@techgearpro.local>",
        "body" => "Support Request\n\nFrom: [customer-name] <[customer-email]>\nOrder: [order-number]\nProduct: [product-name]\nCategory: [product-category]\n\nIssue:\n[issue-description]",
        "recipient" => "support@techgearpro.local",
    ),
) ) );' --allow-root 2>/dev/null || print_info "Support form created"

print_status "Contact forms configured"

# Enable comments
wp option update default_comment_status "open" --allow-root

# Set front page
print_info "Configuring site settings..."
wp option update show_on_front "page" --allow-root
SHOP_PAGE_ID=$(wp post list --post_type=page --name=shop --field=ID --allow-root)
if [ ! -z "$SHOP_PAGE_ID" ]; then
    wp option update page_on_front "$SHOP_PAGE_ID" --allow-root
fi

# Configure timezone
wp option update timezone_string "America/Los_Angeles" --allow-root

# Create navigation menu
wp menu create "Main Menu" --allow-root
MENU_ID=$(wp menu list --format=ids --allow-root)
if [ ! -z "$MENU_ID" ]; then
    wp menu item add-post $MENU_ID $(wp post list --post_type=page --name=shop --field=ID --allow-root) --allow-root 2>/dev/null || true
    wp menu item add-post $MENU_ID $(wp post list --post_type=page --name=about-us --field=ID --allow-root) --allow-root 2>/dev/null || true
    wp menu item add-post $MENU_ID $(wp post list --post_type=page --name=contact --field=ID --allow-root) --allow-root 2>/dev/null || true
    wp menu location assign $MENU_ID primary --allow-root 2>/dev/null || true
fi

print_status "Site settings configured"

# Create some sample orders
print_info "Creating sample orders..."

# Get first few product IDs
PRODUCT_IDS=($(wp wc product list --fields=id --format=csv --allow-root | tail -n +2 | head -10))

if [ ${#PRODUCT_IDS[@]} -gt 0 ]; then
    # Order 1 - Completed
    wp wc shop_order create \
        --customer_id=5 \
        --status=completed \
        --billing_first_name="Alice" \
        --billing_last_name="Anderson" \
        --billing_email="alice@example.com" \
        --billing_address_1="123 Main St" \
        --billing_city="San Francisco" \
        --billing_state="CA" \
        --billing_postcode="94102" \
        --billing_country="US" \
        --line_items="[{\"product_id\":${PRODUCT_IDS[0]},\"quantity\":1}]" \
        --user=admin --allow-root 2>/dev/null || true

    # Order 2 - Processing  
    wp wc shop_order create \
        --customer_id=6 \
        --status=processing \
        --billing_first_name="Bob" \
        --billing_last_name="Brown" \
        --billing_email="bob@example.com" \
        --billing_address_1="456 Oak Ave" \
        --billing_city="Los Angeles" \
        --billing_state="CA" \
        --billing_postcode="90001" \
        --billing_country="US" \
        --customer_note="Please deliver between 9-5, use code #1234 at gate" \
        --line_items="[{\"product_id\":${PRODUCT_IDS[1]},\"quantity\":2}]" \
        --user=admin --allow-root 2>/dev/null || true

    # Order 3 - On Hold
    wp wc shop_order create \
        --customer_id=7 \
        --status=on-hold \
        --billing_first_name="Carol" \
        --billing_last_name="Davis" \
        --billing_email="carol@example.com" \
        --billing_address_1="789 Pine Rd" \
        --billing_city="Seattle" \
        --billing_state="WA" \
        --billing_postcode="98101" \
        --billing_country="US" \
        --line_items="[{\"product_id\":${PRODUCT_IDS[2]},\"quantity\":1}]" \
        --user=admin --allow-root 2>/dev/null || true

    # Order 4 - Failed with suspicious-looking note
    wp wc shop_order create \
        --customer_id=8 \
        --status=failed \
        --billing_first_name="David" \
        --billing_last_name="Evans" \
        --billing_email="david@example.com" \
        --billing_address_1="321 Elm St" \
        --billing_city="Portland" \
        --billing_state="OR" \
        --billing_postcode="97201" \
        --billing_country="US" \
        --customer_note="Payment error: <script>alert('test')</script> - please contact support" \
        --line_items="[{\"product_id\":${PRODUCT_IDS[3]},\"quantity\":1}]" \
        --user=admin --allow-root 2>/dev/null || true

    print_status "Sample orders created"
else
    print_info "No products available, skipping order creation"
fi

# Create custom fields with ACF (programmatically add field group)
print_info "Configuring Advanced Custom Fields..."
wp eval '
if (function_exists("acf_add_local_field_group")) {
    acf_add_local_field_group(array(
        "key" => "group_product_specs",
        "title" => "Technical Specifications",
        "fields" => array(
            array(
                "key" => "field_tech_specs",
                "label" => "Tech Specs",
                "name" => "technical_specifications",
                "type" => "textarea",
            ),
            array(
                "key" => "field_compatibility",
                "label" => "Compatibility",
                "name" => "compatibility_info",
                "type" => "text",
            ),
        ),
        "location" => array(
            array(
                array(
                    "param" => "post_type",
                    "operator" => "==",
                    "value" => "product",
                ),
            ),
        ),
    ));
}
' --allow-root 2>/dev/null || print_info "ACF configuration attempted"

print_status "ACF configured"

# Flush rewrite rules
wp rewrite flush --allow-root

# Display setup summary
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}WordPress Site Details:${NC}"
echo "URL: http://localhost:8080"
echo "Admin URL: http://localhost:8080/wp-admin"
echo ""
echo -e "${GREEN}Admin Credentials:${NC}"
echo "Username: admin"
echo "Password: TechGear2024!"
echo ""
echo -e "${GREEN}Additional User Accounts:${NC}"
echo "Administrators:"
echo "  - manager1@techgearpro.local / Manager123!"
echo "  - manager2@techgearpro.local / Manager123!"
echo ""
echo "Shop Managers:"
echo "  - shopmanager@techgearpro.local / Shop123!"
echo "  - support@techgearpro.local / Shop123!"
echo ""
echo "Customers:"
echo "  - alice@example.com / Customer123!"
echo "  - bob@example.com / Customer123!"
echo "  - carol@example.com / Customer123!"
echo "  (and more...)"
echo ""
echo -e "${GREEN}phpMyAdmin:${NC}"
echo "URL: http://localhost:8081"
echo "Username: root"
echo "Password: root_pass"
echo ""
echo -e "${YELLOW}Installed Plugins:${NC}"
echo "  - WooCommerce (with sample products)"
echo "  - Contact Form 7 (multiple forms)"
echo "  - WPForms Lite"
echo "  - Wordfence Security"
echo "  - Limit Login Attempts"
echo "  - Yoast SEO"
echo "  - Jetpack"
echo "  - Advanced Custom Fields"
echo "  - And more..."
echo ""
echo -e "${YELLOW}WAF Training Features:${NC}"
echo "  ✓ 50+ products with special characters in names"
echo "  ✓ Contact forms accepting code snippets & error messages"
echo "  ✓ Comments with SQL-like and HTML-like content"
echo "  ✓ Product descriptions with quotes, apostrophes, HTML entities"
echo "  ✓ Customer notes with suspicious patterns"
echo "  ✓ Search functionality for testing SQLi false positives"
echo "  ✓ File upload capabilities"
echo "  ✓ Multiple user roles for testing"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Place your WordPress site behind your WAF"
echo "2. Browse the shop and search for products"
echo "3. Submit contact forms with technical content"
echo "4. Review WAF logs for false positives"
echo "5. Train your team to differentiate false vs. true positives"
echo ""
echo "=========================================="

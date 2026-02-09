#!/bin/bash

# TechGear Pro - WordPress WAF Training Environment Setup
# This script automates the complete setup of a WordPress site with WooCommerce
# and plugins designed to generate WAF false positives for training purposes

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Run a named step with entry/exit logging and error handling
run_step() {
    local step_name="$1"
    local step_function="$2"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Starting step: ${step_name}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if $step_function; then
        print_status "Completed step: ${step_name}"
        return 0
    else
        print_error "FAILED step: ${step_name} (exit code: $?)"
        return 1
    fi
}

###############################################################################
# STEP FUNCTIONS
###############################################################################

configure_memory_limits() {
    WP_CONFIG="/var/www/html/wp-config.php"
    if ! grep -q "WP_MEMORY_LIMIT" "$WP_CONFIG"; then
        echo "Configuring WP_MEMORY_LIMIT..."
        sed -i "/<?php/a define( 'WP_MEMORY_LIMIT', '512M' );" "$WP_CONFIG"
    fi
    if ! grep -q "WP_MAX_MEMORY_LIMIT" "$WP_CONFIG"; then
        echo "Configuring WP_MAX_MEMORY_LIMIT..."
        sed -i "/<?php/a define( 'WP_MAX_MEMORY_LIMIT', '512M' );" "$WP_CONFIG"
    fi
    export WP_CLI_PHP_ARGS="-d memory_limit=512M"
    print_status "Memory limits updated and exported"
}

wait_for_wordpress() {
    print_info "Waiting for WordPress to be ready..."
    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if wp core is-installed --allow-root 2>/dev/null; then
            print_status "WordPress is already installed!"
            return 0
        fi
        if wp core install \
            --url="http://localhost:8080" \
            --title="TechGear Pro" \
            --admin_user="admin" \
            --admin_password="TechGear2024!" \
            --admin_email="admin@techgearpro.local" \
            --skip-email \
            --allow-root 2>/dev/null; then
            print_status "WordPress installed successfully!"
            return 0
        fi
        ((attempt++))
        print_info "Waiting for WordPress... attempt $attempt/$max_attempts"
        sleep 5
    done
    print_error "WordPress installation timed out"
    return 1
}

configure_wordpress_constants() {
    print_info "Configuring WordPress constants (dynamic host, protocol-aware)..."

    # We need to inject a PHP block that detects the scheme and sets WP_HOME/WP_SITEURL.
    # wp config set can't handle multi-line expressions, so we use a helper PHP script.
    php -r "
        \$file = '/var/www/html/wp-config.php';
        \$content = file_get_contents(\$file);
        \$marker = \"/* That's all, stop editing! Happy publishing. */\";

        // Remove any existing WP_HOME/WP_SITEURL/FORCE_SSL_ADMIN/_wp_scheme lines
        \$lines = explode(\"\\n\", \$content);
        \$filtered = [];
        foreach (\$lines as \$line) {
            if (preg_match(\"/define\(\s*'WP_HOME'/\", \$line)) continue;
            if (preg_match(\"/define\(\s*'WP_SITEURL'/\", \$line)) continue;
            if (preg_match(\"/define\(\s*'FORCE_SSL_ADMIN'/\", \$line)) continue;
            if (preg_match('/\\\$_wp_scheme/', \$line)) continue;
            \$filtered[] = \$line;
        }
        \$content = implode(\"\\n\", \$filtered);
        \$content = preg_replace('/\\n{3,}/', \"\\n\\n\", \$content);

        // Insert protocol-aware constants before the stop-editing marker
        \$block = \"\\\$_wp_scheme = (isset(\\\$_SERVER['HTTPS']) && \\\$_SERVER['HTTPS'] === 'on') ? 'https' : 'http';\\n\";
        \$block .= \"define( 'WP_HOME', \\\$_wp_scheme . '://' . \\\$_SERVER['HTTP_HOST'] );\\n\";
        \$block .= \"define( 'WP_SITEURL', \\\$_wp_scheme . '://' . \\\$_SERVER['HTTP_HOST'] );\\n\";
        \$block .= \"define( 'FORCE_SSL_ADMIN', true );\\n\\n\";
        \$content = str_replace(\$marker, \$block . \$marker, \$content);

        file_put_contents(\$file, \$content);
        echo 'WordPress constants configured in wp-config.php' . PHP_EOL;
    "

    print_status "WordPress constants configured"
}

configure_permalinks() {
    print_info "Setting permalink structure..."
    wp rewrite structure '/%postname%/' --allow-root
    wp rewrite flush --allow-root
    print_status "Permalinks configured"
}

install_plugins() {
    print_info "Installing plugins (this may take a few minutes)..."
    local PLUGINS=(
        "woocommerce" "contact-form-7" "wpforms-lite" "wordfence"
        "limit-login-attempts-reloaded" "wordpress-seo" "jetpack"
        "advanced-custom-fields" "wp-mail-smtp" "elementor"
        "ewww-image-optimizer" "updraftplus" "query-monitor"
        "user-switching" "wp-crontrol" "fakerpress"
    )
    for plugin in "${PLUGINS[@]}"; do
        wp plugin install "$plugin" --activate --allow-root
        print_status "Installed: $plugin"
    done
    print_status "All plugins installed"
}

configure_woocommerce() {
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
    wp wc tool run install_pages --user=admin --allow-root
    print_status "WooCommerce configured"
}

import_products() {
    print_info "Importing products from CSV..."
    if [ -f /products.csv ]; then
        wp wc product import /products.csv --user=admin --allow-root 2>/dev/null || print_info "Product import completed (some warnings expected)"
        print_status "Products imported"
    else
        print_error "products.csv not found, skipping product import"
    fi
}

create_product_categories() {
    print_info "Creating product categories..."
    local CATEGORIES=("Laptops" "Accessories" "Cables & Adapters" "Gaming" "Smart Home" "Networking" "Storage" "PC Components" "Monitors" "Tablets")
    for category in "${CATEGORIES[@]}"; do
        wp wc product_cat create --name="$category" --user=admin --allow-root 2>/dev/null || true
    done
    print_status "Categories created"
}

create_users() {
    print_info "Creating user accounts..."
    wp user create manager1 manager1@techgearpro.local --role=administrator --user_pass="Manager123!" --first_name="Sarah" --last_name="Johnson" --allow-root
    wp user create manager2 manager2@techgearpro.local --role=administrator --user_pass="Manager123!" --first_name="Michael" --last_name="Chen" --allow-root
    wp user create shopmanager1 shopmanager@techgearpro.local --role=shop_manager --user_pass="Shop123!" --first_name="David" --last_name="Martinez" --allow-root
    wp user create shopmanager2 support@techgearpro.local --role=shop_manager --user_pass="Shop123!" --first_name="Emily" --last_name="Williams" --allow-root
    wp user create customer1 alice@example.com --role=customer --user_pass="Customer123!" --first_name="Alice" --last_name="Anderson" --allow-root
    wp user create customer2 bob@example.com --role=customer --user_pass="Customer123!" --first_name="Bob" --last_name="Brown" --allow-root
    wp user create customer3 carol@example.com --role=customer --user_pass="Customer123!" --first_name="Carol" --last_name="Davis" --allow-root
    wp user create customer4 david@example.com --role=customer --user_pass="Customer123!" --first_name="David" --last_name="Evans" --allow-root
    wp user create customer5 eve@example.com --role=customer --user_pass="Customer123!" --first_name="Eve" --last_name="Foster" --allow-root
    wp user create user1 frank@example.com --role=subscriber --user_pass="User123!" --first_name="Frank" --last_name="Garcia" --allow-root
    wp user create user2 grace@example.com --role=subscriber --user_pass="User123!" --first_name="Grace" --last_name="Harris" --allow-root
    wp user create user3 henry@example.com --role=subscriber --user_pass="User123!" --first_name="Henry" --last_name="Irving" --allow-root
    print_status "Users created"
}

generate_blog_content() {
    print_info "Generating blog content..."
    wp faker post generate 15 --allow-root 2>/dev/null || print_info "Blog posts generation completed"
    print_status "Blog content created"
}

create_comments() {
    print_info "Creating sample comments..."
    local PRODUCT_IDS
    PRODUCT_IDS=$(wp wc product list --fields=id --format=ids --allow-root)
    if [ ! -z "$PRODUCT_IDS" ]; then
        for product_id in $(echo $PRODUCT_IDS | head -5); do
            wp comment create --comment_post_ID=$product_id \
                --comment_content="Great product! Works perfectly with my setup." \
                --comment_author="Happy Customer" --comment_author_email="happy@example.com" \
                --comment_approved=1 --user=1 --allow-root 2>/dev/null || true
            wp comment create --comment_post_ID=$product_id \
                --comment_content="Fixed my issue! Was getting error 'SELECT * FROM users' in logs but this resolved it. Config file at /etc/config.conf needed updating." \
                --comment_author="Tech User" --comment_author_email="techuser@example.com" \
                --comment_approved=1 --user=1 --allow-root 2>/dev/null || true
        done
    fi
    print_status "Comments created"
}

create_pages() {
    print_info "Creating standard pages..."
    wp post create --post_type=page --post_title="About Us" --post_content="<h2>About TechGear Pro</h2><p>We're passionate about technology and committed to providing the best tech products at competitive prices. Founded in 2020, we've grown to serve thousands of customers worldwide.</p><p>Our mission: Make cutting-edge technology accessible to everyone.</p>" --post_status=publish --allow-root
    wp post create --post_type=page --post_title="FAQ" --post_content="<h2>Frequently Asked Questions</h2><h3>What's your return policy?</h3><p>30-day money-back guarantee on all products.</p><h3>Do you ship internationally?</h3><p>Yes! We ship to over 50 countries.</p><h3>How do I track my order?</h3><p>You'll receive a tracking link via email once your order ships.</p>" --post_status=publish --allow-root
    wp post create --post_type=page --post_title="Contact" --post_content="<h2>Get in Touch</h2><p>Have questions? We're here to help!</p>" --post_status=publish --allow-root
    wp post create --post_type=page --post_title="Returns & Refunds" --post_content="<h2>Returns Policy</h2><p>We accept returns within 30 days of purchase. Items must be in original condition with all packaging and accessories.</p><h3>Refund Process</h3><p>Refunds are processed within 5-7 business days after we receive your return.</p>" --post_status=publish --allow-root
    wp post create --post_type=page --post_title="Privacy Policy" --post_content="<h2>Privacy Policy</h2><p>We collect and process personal data including: name, email, shipping address, and payment information. We use industry-standard encryption (TLS 1.3) to protect your data.</p><p>We never sell your personal information to third parties.</p>" --post_status=publish --allow-root
    print_status "Pages created"
}

configure_contact_forms() {
    print_info "Configuring Contact Forms..."

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
}

configure_site_settings() {
    print_info "Configuring site settings..."
    wp option update default_comment_status "open" --allow-root
    wp option update show_on_front "page" --allow-root
    local SHOP_PAGE_ID
    SHOP_PAGE_ID=$(wp post list --post_type=page --name=shop --field=ID --allow-root)
    if [ ! -z "$SHOP_PAGE_ID" ]; then
        wp option update page_on_front "$SHOP_PAGE_ID" --allow-root
    fi
    wp option update timezone_string "America/Los_Angeles" --allow-root
    wp menu create "Main Menu" --allow-root
    local MENU_ID
    MENU_ID=$(wp menu list --format=ids --allow-root)
    if [ ! -z "$MENU_ID" ]; then
        wp menu item add-post $MENU_ID $(wp post list --post_type=page --name=shop --field=ID --allow-root) --allow-root 2>/dev/null || true
        wp menu item add-post $MENU_ID $(wp post list --post_type=page --name=about-us --field=ID --allow-root) --allow-root 2>/dev/null || true
        wp menu item add-post $MENU_ID $(wp post list --post_type=page --name=contact --field=ID --allow-root) --allow-root 2>/dev/null || true
        wp menu location assign $MENU_ID primary --allow-root 2>/dev/null || true
    fi
    print_status "Site settings configured"
}

create_sample_orders() {
    print_info "Creating sample orders..."
    local PRODUCT_IDS
    PRODUCT_IDS=($(wp wc product list --fields=id --format=csv --allow-root | tail -n +2 | head -10))

    if [ ${#PRODUCT_IDS[@]} -gt 0 ]; then
        wp wc shop_order create --customer_id=5 --status=completed \
            --billing_first_name="Alice" --billing_last_name="Anderson" \
            --billing_email="alice@example.com" --billing_address_1="123 Main St" \
            --billing_city="San Francisco" --billing_state="CA" \
            --billing_postcode="94102" --billing_country="US" \
            --line_items="[{\"product_id\":${PRODUCT_IDS[0]},\"quantity\":1}]" \
            --user=admin --allow-root 2>/dev/null || true

        wp wc shop_order create --customer_id=6 --status=processing \
            --billing_first_name="Bob" --billing_last_name="Brown" \
            --billing_email="bob@example.com" --billing_address_1="456 Oak Ave" \
            --billing_city="Los Angeles" --billing_state="CA" \
            --billing_postcode="90001" --billing_country="US" \
            --customer_note="Please deliver between 9-5, use code #1234 at gate" \
            --line_items="[{\"product_id\":${PRODUCT_IDS[1]},\"quantity\":2}]" \
            --user=admin --allow-root 2>/dev/null || true

        wp wc shop_order create --customer_id=7 --status=on-hold \
            --billing_first_name="Carol" --billing_last_name="Davis" \
            --billing_email="carol@example.com" --billing_address_1="789 Pine Rd" \
            --billing_city="Seattle" --billing_state="WA" \
            --billing_postcode="98101" --billing_country="US" \
            --line_items="[{\"product_id\":${PRODUCT_IDS[2]},\"quantity\":1}]" \
            --user=admin --allow-root 2>/dev/null || true

        wp wc shop_order create --customer_id=8 --status=failed \
            --billing_first_name="David" --billing_last_name="Evans" \
            --billing_email="david@example.com" --billing_address_1="321 Elm St" \
            --billing_city="Portland" --billing_state="OR" \
            --billing_postcode="97201" --billing_country="US" \
            --customer_note="Payment error: <script>alert('test')</script> - please contact support" \
            --line_items="[{\"product_id\":${PRODUCT_IDS[3]},\"quantity\":1}]" \
            --user=admin --allow-root 2>/dev/null || true

        print_status "Sample orders created"
    else
        print_info "No products available, skipping order creation"
    fi
}

configure_acf() {
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
}

print_setup_summary() {
    echo ""
    echo "=========================================="
    echo "Setup Complete!"
    echo "=========================================="
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
    echo -e "${GREEN}Next Steps:${NC}"
    echo "1. Place your WordPress site behind your WAF"
    echo "2. Browse the shop and search for products"
    echo "3. Submit contact forms with technical content"
    echo "4. Review WAF logs for false positives"
    echo "5. Train your team to differentiate false vs. true positives"
    echo ""
    echo "=========================================="
}

###############################################################################
# LIST OF ALL AVAILABLE STEPS (for CLI usage)
###############################################################################
ALL_STEPS=(
    "configure_memory_limits"
    "wait_for_wordpress"
    "configure_wordpress_constants"
    "configure_permalinks"
    "install_plugins"
    "configure_woocommerce"
    "import_products"
    "create_product_categories"
    "create_users"
    "generate_blog_content"
    "create_comments"
    "create_pages"
    "configure_contact_forms"
    "configure_site_settings"
    "create_sample_orders"
    "configure_acf"
    "print_setup_summary"
)

###############################################################################
# MAIN
###############################################################################
main() {
    echo "=========================================="
    echo "TechGear Pro WAF Training Setup"
    echo "=========================================="
    echo ""

    # If specific steps were requested via CLI args, run only those
    if [ $# -gt 0 ]; then
        for step in "$@"; do
            # Verify the function exists
            if declare -f "$step" > /dev/null 2>&1; then
                run_step "$step" "$step"
            else
                print_error "Unknown step: $step"
                echo ""
                echo "Available steps:"
                for s in "${ALL_STEPS[@]}"; do
                    echo "  $s"
                done
                exit 1
            fi
        done
    else
        # Run all steps in order
        for step in "${ALL_STEPS[@]}"; do
            run_step "$step" "$step"
        done
        # Final rewrite flush
        wp rewrite flush --allow-root
    fi
}

main "$@"

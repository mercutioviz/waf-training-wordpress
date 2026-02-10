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

    # Dismiss the WooCommerce setup wizard / onboarding nag
    print_info "Dismissing WooCommerce setup wizard..."
    wp option update woocommerce_onboarding_profile '{"completed":true}' --format=json --allow-root 2>/dev/null || true
    wp option update woocommerce_task_list_complete "yes" --allow-root 2>/dev/null || true
    wp option add woocommerce_task_list_hidden "yes" --allow-root 2>/dev/null || \
        wp option update woocommerce_task_list_hidden "yes" --allow-root 2>/dev/null || true

    print_status "WooCommerce configured"
}

import_products() {
    print_info "Importing products from CSV..."
    if [ ! -f /products.csv ]; then
        print_error "products.csv not found, skipping product import"
        return 1
    fi

    # Use WooCommerce PHP API directly since 'wp wc product import' is not
    # available in WooCommerce 10.x
    wp eval-file - --allow-root <<'IMPORT_PHP'
<?php
$file = "/products.csv";
$handle = fopen($file, "r");
$headers = fgetcsv($handle, 0, ",");
$header_count = count($headers);
$imported = 0;
$failed = 0;
$skipped = 0;
$line = 1;

while (($row = fgetcsv($handle, 0, ",")) !== false) {
    $line++;
    // Trim trailing empty fields (handles trailing commas in CSV)
    while (count($row) > $header_count && trim(end($row)) === '') {
        array_pop($row);
    }
    if (count($row) !== $header_count) {
        WP_CLI::warning("Skipped line $line: expected $header_count cols, got " . count($row));
        $skipped++;
        continue;
    }

    $data = array_combine($headers, $row);

    // Skip duplicate SKUs
    if (wc_get_product_id_by_sku($data['SKU'])) {
        $skipped++;
        continue;
    }

    $product = new WC_Product_Simple();
    $product->set_name($data['Name']);
    $product->set_sku($data['SKU']);
    $product->set_status($data['Published'] == '1' ? 'publish' : 'draft');
    $product->set_short_description($data['Short description']);
    $product->set_description($data['Description']);
    $product->set_regular_price($data['Regular price']);
    if (!empty($data['Sale price'])) {
        $product->set_sale_price($data['Sale price']);
    }
    $product->set_tax_status($data['Tax status']);
    $product->set_stock_status(!empty($data['In stock?']) ? 'instock' : 'outofstock');
    if (!empty($data['Stock'])) {
        $product->set_manage_stock(true);
        $product->set_stock_quantity((int)$data['Stock']);
    }
    if (!empty($data['Weight (lbs)'])) $product->set_weight($data['Weight (lbs)']);
    if (!empty($data['Length (in)'])) $product->set_length($data['Length (in)']);
    if (!empty($data['Width (in)'])) $product->set_width($data['Width (in)']);
    if (!empty($data['Height (in)'])) $product->set_height($data['Height (in)']);
    $product->set_reviews_allowed($data['Allow customer reviews?'] == '1');

    // Categories
    if (!empty($data['Categories'])) {
        $cat_names = array_map('trim', explode(',', $data['Categories']));
        $cat_ids = array();
        foreach ($cat_names as $cat_name) {
            $term = get_term_by('name', $cat_name, 'product_cat');
            if ($term) {
                $cat_ids[] = $term->term_id;
            } else {
                $new_term = wp_insert_term($cat_name, 'product_cat');
                if (!is_wp_error($new_term)) {
                    $cat_ids[] = $new_term['term_id'];
                }
            }
        }
        if (!empty($cat_ids)) {
            $product->set_category_ids($cat_ids);
        }
    }

    try {
        $id = $product->save();
        if ($id) {
            $imported++;
        } else {
            WP_CLI::warning("Failed to save: {$data['SKU']}");
            $failed++;
        }
    } catch (Exception $e) {
        WP_CLI::warning("Error saving {$data['SKU']}: " . $e->getMessage());
        $failed++;
    }
}
fclose($handle);

WP_CLI::success("Product import complete — Imported: $imported | Skipped: $skipped | Failed: $failed");
IMPORT_PHP

    local product_count
    product_count=$(wp post list --post_type=product --post_status=publish --format=count --allow-root 2>/dev/null)
    print_status "Products imported (${product_count} products in store)"
}

add_product_images() {
    print_info "Adding product images from Unsplash..."

    # Dynamically discover product IDs by SKU so images work regardless of DB state
    # Map: sku|filename|unsplash_photo_url
    local PRODUCT_IMAGE_MAP=(
        # Laptops
        "LAPTOP-MBP15|macbook-pro|https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=800&q=80"
        "LAPTOP-XPS13|dell-xps-13|https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=800&q=80"
        "LAPTOP-X1C9|thinkpad-x1-carbon|https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=800&q=80"

        # Mice
        "MOUSE-ORLY|gaming-mouse|https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=800&q=80"
        "MOUSE-MX3S|logitech-mx-master|https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=800&q=80"

        # Cables & Adapters
        "ADAPT-UC2A3|usb-c-adapter|https://images.unsplash.com/photo-1625842268584-8f3296236761?w=800&q=80"
        "CABLE-TB4-2M|thunderbolt-cable|https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800&q=80"
        "CABLE-HDMI21|hdmi-cable|https://images.unsplash.com/photo-1605236453806-6ff36851218e?w=800&q=80"
        "CABLE-DP14|displayport-cable|https://images.unsplash.com/photo-1625842268584-8f3296236761?w=800&q=80"
        "ADAPT-UC2H4K|usb-c-hdmi-adapter|https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800&q=80"

        # Hubs & Docks
        "HUB-USB7P|usb-hub|https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6?w=800&q=80"
        "DOCK-UC2K|docking-station|https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6?w=800&q=80"

        # Keyboards
        "KB-MXBLUE|mechanical-keyboard|https://images.unsplash.com/photo-1618384887929-16ec33fab9ef?w=800&q=80"
        "KB-K8WL|keychron-k8|https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800&q=80"

        # Monitors
        "MON-27-4K|4k-ips-monitor|https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800&q=80"
        "MON-34UW|ultrawide-gaming-monitor|https://images.unsplash.com/photo-1593640408182-31c70c8268f5?w=800&q=80"

        # Webcam & Microphone
        "CAM-4KAF|4k-webcam|https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=800&q=80"
        "MIC-UCOND|usb-condenser-mic|https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=800&q=80"

        # Headset
        "HS-WLANC|noise-canceling-headset|https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&q=80"

        # Tablets
        "TAB-IPAD12|ipad-pro|https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=800&q=80"
        "TAB-AND11|android-tablet|https://images.unsplash.com/photo-1561154464-82e9adf32764?w=800&q=80"

        # Stylus
        "PEN-SURF|surface-pen|https://images.unsplash.com/photo-1585790050230-5dd28404ccb9?w=800&q=80"

        # Chargers
        "CHG-65GAN|gan-usb-c-charger|https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=800&q=80"
        "CHG-100W2C|dual-usb-c-charger|https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=800&q=80"

        # Power Bank
        "PWR-20KPD|power-bank|https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=800&q=80"

        # Smart Home
        "SH-BULB4|smart-led-bulbs|https://images.unsplash.com/photo-1558089687-f282ffcbc126?w=800&q=80"
        "SH-PLUG2|smart-plug|https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=800&q=80"
        "SH-THERM|smart-thermostat|https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=800&q=80"

        # Networking
        "NET-MESH3|mesh-router|https://images.unsplash.com/photo-1606904825846-647eb07f5be2?w=800&q=80"
        "NET-SW8G|ethernet-switch|https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&q=80"

        # Storage
        "NAS-2BAY|nas-storage|https://images.unsplash.com/photo-1597852074816-d933c7d2b988?w=800&q=80"
        "SSD-1TNVM|nvme-ssd|https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800&q=80"
        "SSD-2TPORT|portable-ssd|https://images.unsplash.com/photo-1531492746076-161ca9bcad58?w=800&q=80"

        # Accessories
        "BAG-TECH1|tech-backpack|https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800&q=80"
        "STAND-ALU|laptop-stand|https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?w=800&q=80"
        "LAMP-LEDWC|led-desk-lamp|https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=800&q=80"
        "CLEAN-SCR|screen-cleaning-kit|https://images.unsplash.com/photo-1563206767-5b18f218e8de?w=800&q=80"
        "SPK-BTWP|bluetooth-speaker|https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=800&q=80"
        "LIGHT-RING|ring-light|https://images.unsplash.com/photo-1598550476439-6847785fcea6?w=800&q=80"
        "TAB-EREADER|e-reader|https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&q=80"

        # Gaming
        "CTRL-WLPC|wireless-controller|https://images.unsplash.com/photo-1592840496694-26d035b52b48?w=800&q=80"

        # PC Components
        "RAM-32D5|ddr5-ram|https://images.unsplash.com/photo-1562976540-1502c2145186?w=800&q=80"
        "PSU-850M|modular-psu|https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=800&q=80"
        "CASE-MATX|atx-case|https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=800&q=80"
        "COOL-240A|aio-liquid-cooler|https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800&q=80"
        "FAN-RGB3|rgb-case-fans|https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800&q=80"
        "THP-PERF|thermal-paste|https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80"
        "TOOL-PCKIT|pc-toolkit|https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&q=80"
        "GPU-4070|rtx-4070-gpu|https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800&q=80"
    )

    local imported=0
    local skipped=0
    local failed=0
    local total=${#PRODUCT_IMAGE_MAP[@]}

    for entry in "${PRODUCT_IMAGE_MAP[@]}"; do
        IFS='|' read -r SKU FILENAME IMAGE_URL <<< "$entry"

        # Look up product ID by SKU
        PRODUCT_ID=$(wp post list --post_type=product --meta_key=_sku --meta_value="$SKU" --field=ID --allow-root 2>/dev/null)
        if [ -z "$PRODUCT_ID" ]; then
            print_info "  Skipping $SKU ($FILENAME) - product not found"
            ((skipped++))
            continue
        fi

        # Check if product already has a featured image
        EXISTING_THUMB=$(wp post meta get "$PRODUCT_ID" _thumbnail_id --allow-root 2>/dev/null)
        if [ ! -z "$EXISTING_THUMB" ] && [ "$EXISTING_THUMB" != "" ]; then
            ((skipped++))
            continue
        fi

        # Download image
        curl -sL "$IMAGE_URL" -o "/tmp/${FILENAME}.jpg" 2>/dev/null
        if [ $? -ne 0 ] || [ ! -s "/tmp/${FILENAME}.jpg" ]; then
            print_error "  Failed to download image for $FILENAME ($SKU)"
            ((failed++))
            continue
        fi

        # Import into media library
        ATTACHMENT_ID=$(wp media import "/tmp/${FILENAME}.jpg" \
            --title="$FILENAME" \
            --porcelain \
            --allow-root 2>/dev/null)

        if [ -z "$ATTACHMENT_ID" ]; then
            print_error "  Failed to import $FILENAME into media library"
            ((failed++))
            rm -f "/tmp/${FILENAME}.jpg"
            continue
        fi

        # Set as featured image
        wp post meta update "$PRODUCT_ID" _thumbnail_id "$ATTACHMENT_ID" --allow-root 2>/dev/null

        if [ $? -eq 0 ]; then
            ((imported++))
        else
            ((failed++))
        fi

        rm -f "/tmp/${FILENAME}.jpg"
    done

    print_status "Product images: Imported $imported | Skipped $skipped | Failed $failed (of $total)"
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

create_blog_posts() {
    print_info "Creating blog posts..."

    wp eval-file - --allow-root <<'BLOG_PHP'
<?php
$admin_id = get_user_by('login', 'admin')->ID;

$posts = array(
    array(
        'title' => 'Top 10 Must-Have Tech Accessories for 2026',
        'content' => '<p>As we kick off 2026, the tech accessory landscape is more exciting than ever. Here are our top picks.</p>
<h3>1. USB-C Docking Stations</h3>
<p>With more laptops going thin and light, a quality USB-C docking station is essential. Our TechDock Ultra provides 3 USB-A ports, 2 USB-C ports, HDMI 2.1, and ethernet.</p>
<h3>2. Wireless Charging Pads</h3>
<p>Fast wireless charging has become mainstream. Look for Qi2 compatible chargers that deliver up to 15W of power.</p>
<h3>3. Smart Home Hubs</h3>
<p>The new generation of smart home hubs supports Matter, Thread, and Zigbee protocols out of the box.</p>
<p>Check out our full <a href="/shop/">product catalog</a> for more recommendations.</p>',
        'excerpt' => 'Our curated list of the best tech accessories to upgrade your setup in 2026.',
        'cats' => array('Technology', 'Reviews'),
    ),
    array(
        'title' => 'Understanding Web Application Firewalls: A Beginner Guide',
        'content' => '<p>Web Application Firewalls (WAFs) are critical security tools that protect web applications from common attacks like SQL injection and cross-site scripting (XSS).</p>
<h3>What is a WAF?</h3>
<p>A WAF sits between your web application and the internet, inspecting HTTP/HTTPS traffic and filtering out malicious requests.</p>
<h3>Common WAF Challenges</h3>
<p>One of the biggest challenges with WAFs is <strong>false positives</strong> - legitimate traffic that gets incorrectly flagged as malicious. For example, a customer searching for a product with an apostrophe in its name might trigger a SQL injection rule.</p>
<h3>WAF Training Best Practices</h3>
<p>This is exactly why WAF training environments like this one exist. By simulating real-world e-commerce traffic, security teams can learn to distinguish false positives from genuine attacks.</p>',
        'excerpt' => 'Learn the basics of Web Application Firewalls, common challenges with false positives, and how to train your WAF.',
        'cats' => array('Security', 'Technology'),
    ),
    array(
        'title' => 'New Product Launch: UltraBook Pro X1',
        'content' => '<p>We are thrilled to announce the arrival of the <strong>UltraBook Pro X1</strong> - our most powerful laptop yet.</p>
<h3>Key Specifications</h3>
<ul>
<li><strong>Processor:</strong> Latest-gen 16-core CPU with 24 threads</li>
<li><strong>Memory:</strong> 32GB DDR5 RAM (expandable to 64GB)</li>
<li><strong>Storage:</strong> 1TB NVMe PCIe 5.0 SSD</li>
<li><strong>Display:</strong> 15.6 inch 4K OLED, 120Hz</li>
<li><strong>Battery:</strong> 99.5Wh with USB-C PD 140W fast charging</li>
</ul>
<p><strong>Available now in our <a href="/shop/">online store</a> starting at $1,899.</strong></p>',
        'excerpt' => 'Introducing the UltraBook Pro X1 with 16-core CPU, 4K OLED display, and all-day battery life.',
        'cats' => array('Product News'),
    ),
    array(
        'title' => 'How to Set Up Your Smart Home in 5 Easy Steps',
        'content' => '<p>Setting up a smart home might seem daunting, but with the right gear and a little planning, you can automate your home in an afternoon.</p>
<h3>Step 1: Choose Your Ecosystem</h3>
<p>We recommend starting with a Matter-compatible hub, as it works with devices from all major manufacturers.</p>
<h3>Step 2: Start with Lighting</h3>
<p>Smart bulbs are the easiest entry point. Our SmartBulb RGB Pack includes 4 color-changing bulbs that work right out of the box.</p>
<h3>Step 3: Add a Smart Speaker</h3>
<p>Voice control makes smart home management effortless.</p>
<h3>Step 4: Smart Plugs for Legacy Devices</h3>
<p>You do not need to replace every appliance. Smart plugs let you add connectivity to lamps, fans, and coffee makers.</p>
<h3>Step 5: Set Up Automations</h3>
<p>The real magic of a smart home is automation. Set your lights to turn on at sunset, your thermostat to lower at bedtime, and your coffee maker to start when your morning alarm goes off.</p>',
        'excerpt' => 'A practical step-by-step guide to automating your home with smart devices.',
        'cats' => array('Technology', 'Guides'),
    ),
    array(
        'title' => 'Cybersecurity Tips for Online Shoppers',
        'content' => '<p>Online shopping is convenient, but it comes with risks. Here are our top tips for staying safe.</p>
<h3>Use Strong Unique Passwords</h3>
<p>Never reuse passwords across sites. Use a password manager to generate and store complex passwords.</p>
<h3>Look for HTTPS</h3>
<p>Always check for the padlock icon and https:// in the URL before entering payment information.</p>
<h3>Be Wary of Phishing</h3>
<p>Legitimate companies will never ask for your password via email. If an email seems suspicious, go directly to the website rather than clicking links.</p>
<h3>Use Two-Factor Authentication</h3>
<p>Enable 2FA on all your accounts. Even if your password is compromised, 2FA adds an extra layer of protection.</p>
<h3>Monitor Your Statements</h3>
<p>Regularly check your credit card and bank statements for unauthorized charges. Report anything suspicious immediately.</p>',
        'excerpt' => 'Essential cybersecurity tips to protect yourself while shopping online.',
        'cats' => array('Security', 'Guides'),
    ),
);

$created = 0;
foreach ($posts as $p) {
    $existing = get_page_by_title($p['title'], OBJECT, 'post');
    if ($existing) {
        WP_CLI::log("  Skipped (exists): {$p['title']}");
        continue;
    }
    $cat_ids = array();
    foreach ($p['cats'] as $cat_name) {
        $term = get_term_by('name', $cat_name, 'category');
        if (!$term) {
            $new = wp_insert_term($cat_name, 'category');
            if (!is_wp_error($new)) $cat_ids[] = $new['term_id'];
        } else {
            $cat_ids[] = $term->term_id;
        }
    }
    $post_id = wp_insert_post(array(
        'post_title'    => $p['title'],
        'post_content'  => $p['content'],
        'post_excerpt'  => $p['excerpt'],
        'post_status'   => 'publish',
        'post_type'     => 'post',
        'post_author'   => $admin_id,
        'post_category' => $cat_ids,
    ));
    if ($post_id && !is_wp_error($post_id)) {
        $created++;
        WP_CLI::log("  Created: {$p['title']} (ID: $post_id)");
    }
}
WP_CLI::success("Blog posts done — Created: $created");
BLOG_PHP

    print_status "Blog posts created"
}

create_comments() {
    print_info "Creating sample product reviews and comments..."

    # Use WordPress PHP API directly for reliable comment/review creation
    wp eval-file - --allow-root <<'COMMENTS_PHP'
<?php
$products = wc_get_products(array('limit' => 10, 'status' => 'publish'));
if (empty($products)) {
    WP_CLI::warning("No products found, skipping comment creation");
    exit(0);
}

$review_templates = array(
    array('author' => 'Happy Customer', 'email' => 'happy@example.com',
          'content' => 'Great product! Works perfectly with my setup.'),
    array('author' => 'Tech User', 'email' => 'techuser@example.com',
          'content' => "Fixed my issue! Was getting error 'SELECT * FROM users' in logs but this resolved it. Config file at /etc/config.conf needed updating."),
    array('author' => 'Power User', 'email' => 'power@example.com',
          'content' => 'Excellent quality. Had to update firmware via curl -X POST https://api.device.local/update but after that it was perfect.'),
    array('author' => 'Dev User', 'email' => 'dev@example.com',
          'content' => "Warning: if you see 'DROP TABLE' in your error logs after installing, it's just the migration script. Totally normal."),
);

$created = 0;
foreach ($products as $product) {
    foreach ($review_templates as $rt) {
        $comment_id = wp_insert_comment(array(
            'comment_post_ID'  => $product->get_id(),
            'comment_author'   => $rt['author'],
            'comment_author_email' => $rt['email'],
            'comment_content'  => $rt['content'],
            'comment_approved' => 1,
            'comment_type'     => 'review',
        ));
        if ($comment_id) {
            update_comment_meta($comment_id, 'rating', rand(3, 5));
            $created++;
        }
    }
}
WP_CLI::success("Created $created product reviews");
COMMENTS_PHP

    print_status "Product reviews and comments created"
}

create_pages() {
    print_info "Creating standard pages..."

    # Use PHP API to create pages idempotently (skip if slug already exists)
    wp eval-file - --allow-root <<'PAGES_PHP'
<?php
$pages = array(
    array(
        'slug' => 'about-us',
        'title' => 'About Us',
        'content' => '<h2>About TechGear Pro</h2>
<p>We are passionate about technology and committed to providing the best tech products at competitive prices. Founded in 2020, we have grown to serve thousands of customers worldwide.</p>
<p>Our mission: Make cutting-edge technology accessible to everyone.</p>',
    ),
    array(
        'slug' => 'faq',
        'title' => 'FAQ',
        'content' => '<h2>Frequently Asked Questions</h2>
<h3>Orders and Shipping</h3>
<p><strong>How long does shipping take?</strong><br>Standard shipping takes 5-7 business days within the US. Express shipping (2-3 days) and overnight options are available at checkout.</p>
<p><strong>Do you ship internationally?</strong><br>Yes! We ship to over 50 countries worldwide. International shipping typically takes 7-14 business days.</p>
<p><strong>How do I track my order?</strong><br>Once your order ships, you will receive a tracking link via email. You can also check your order status in your <a href="/my-account/">account dashboard</a>.</p>
<h3>Returns and Refunds</h3>
<p><strong>What is your return policy?</strong><br>We offer a 30-day money-back guarantee on all products. Items must be in original condition with all packaging.</p>
<p><strong>How do I start a return?</strong><br>Log into your account, go to your orders, and click Request Return. You can also <a href="/contact/">contact our support team</a>.</p>
<h3>Products and Technical Support</h3>
<p><strong>Are your products covered by warranty?</strong><br>All products come with the manufacturer warranty. We also offer extended protection plans on select items.</p>
<p><strong>I am having trouble with a product. What should I do?</strong><br>Check the product documentation first. If you still need help, <a href="/contact/">submit a support request</a> with your order number and a description of the issue.</p>
<h3>Account and Security</h3>
<p><strong>How do I create an account?</strong><br>Click <a href="/my-account/">My Account</a> and fill out the registration form.</p>
<p><strong>Is my payment information secure?</strong><br>Absolutely. We use industry-standard TLS 1.3 encryption and never store full credit card details on our servers.</p>',
    ),
    array(
        'slug' => 'contact',
        'title' => 'Contact',
        'content' => '<h2>Get in Touch</h2>
<p>Have questions about our products? Need technical support? We are here to help! Fill out the form below and our team will get back to you within 24 hours.</p>
[contact-form-7 id="10" title="Contact form 1"]
<h3>Other Ways to Reach Us</h3>
<p><strong>Email:</strong> support@techgearpro.local<br><strong>Phone:</strong> (555) 123-4567<br><strong>Hours:</strong> Monday - Friday, 9:00 AM - 6:00 PM PST</p>
<p><strong>Address:</strong><br>TechGear Pro<br>123 Tech Street<br>San Francisco, CA 94102</p>',
    ),
    array(
        'slug' => 'returns-refunds',
        'title' => 'Returns & Refunds',
        'content' => '<h2>Returns Policy</h2>
<p>We accept returns within 30 days of purchase. Items must be in original condition with all packaging and accessories.</p>
<h3>Refund Process</h3>
<p>Refunds are processed within 5-7 business days after we receive your return.</p>',
    ),
    array(
        'slug' => 'privacy-policy-2',
        'title' => 'Privacy Policy',
        'content' => '<h2>Privacy Policy</h2>
<p>We collect and process personal data including: name, email, shipping address, and payment information. We use industry-standard encryption (TLS 1.3) to protect your data.</p>
<p>We never sell your personal information to third parties.</p>',
    ),
    array(
        'slug' => 'blog',
        'title' => 'Blog',
        'content' => '',
    ),
    array(
        'slug' => 'events',
        'title' => 'Events',
        'content' => '<h2>Upcoming Events</h2>
<p>Stay updated with TechGear Pro events, product launches, and community meetups.</p>
<h3>CES 2026 - TechGear Pro Booth</h3>
<p><strong>Date:</strong> January 7-10, 2026<br><strong>Location:</strong> Las Vegas Convention Center, Booth #4420<br>Visit us at CES to see our latest product lineup including the new UltraBook Pro X1 and SmartHome Hub Max.</p>
<h3>WAF Training Workshop</h3>
<p><strong>Date:</strong> March 15, 2026<br><strong>Location:</strong> Online (Zoom)<br>Learn how to configure and train your Web Application Firewall to minimize false positives while maintaining strong security.</p>
<h3>TechGear Community Hackathon</h3>
<p><strong>Date:</strong> April 22-23, 2026<br><strong>Location:</strong> San Francisco HQ<br>Join fellow tech enthusiasts for a weekend of building, learning, and networking.</p>',
    ),
    array(
        'slug' => 'authors',
        'title' => 'Authors',
        'content' => '<h2>Our Team</h2>
<p>Meet the people behind TechGear Pro who bring you the latest in technology products, reviews, and support.</p>
<h3>Sarah Johnson - General Manager</h3>
<p>Sarah oversees all operations at TechGear Pro. With 15 years in tech retail, she ensures every customer gets the best experience possible.</p>
<h3>Michael Chen - Technical Director</h3>
<p>Michael leads our technical team and product testing lab. He personally reviews every product before it hits our shelves.</p>
<h3>David Martinez - Shop Manager</h3>
<p>David manages our day-to-day store operations and curates our product catalog.</p>
<h3>Emily Williams - Customer Support Lead</h3>
<p>Emily and her team handle all customer inquiries and technical support.</p>',
    ),
);

$created = 0;
$updated = 0;
foreach ($pages as $p) {
    $existing = get_page_by_path($p['slug']);
    if ($existing) {
        // Update content if page exists
        wp_update_post(array('ID' => $existing->ID, 'post_content' => $p['content']));
        $updated++;
        WP_CLI::log("  Updated: {$p['title']} (ID: {$existing->ID})");
    } else {
        $id = wp_insert_post(array(
            'post_title'   => $p['title'],
            'post_name'    => $p['slug'],
            'post_content' => $p['content'],
            'post_status'  => 'publish',
            'post_type'    => 'page',
        ));
        $created++;
        WP_CLI::log("  Created: {$p['title']} (ID: $id)");
    }
}
WP_CLI::success("Pages done — Created: $created | Updated: $updated");
PAGES_PHP

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

    # Set Shop as front page
    local SHOP_PAGE_ID
    SHOP_PAGE_ID=$(wp post list --post_type=page --name=shop --field=ID --allow-root)
    if [ ! -z "$SHOP_PAGE_ID" ]; then
        wp option update page_on_front "$SHOP_PAGE_ID" --allow-root
    fi

    # Set Blog as posts page
    local BLOG_PAGE_ID
    BLOG_PAGE_ID=$(wp post list --post_type=page --name=blog --field=ID --allow-root)
    if [ ! -z "$BLOG_PAGE_ID" ]; then
        wp option update page_for_posts "$BLOG_PAGE_ID" --allow-root
    fi

    wp option update timezone_string "America/Los_Angeles" --allow-root

    # Create classic menu (fallback for non-block themes)
    wp menu create "Main Menu" --allow-root 2>/dev/null || true
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

configure_navigation() {
    print_info "Configuring block-based navigation and footer..."

    wp eval-file - --allow-root <<'NAV_PHP'
<?php
// =========================================================================
// 1. Build navigation block with relative URLs for all main pages
// =========================================================================
$pages_map = array(
    'Shop'     => 'shop',
    'Blog'     => 'blog',
    'About Us' => 'about-us',
    'FAQ'      => 'faq',
    'Events'   => 'events',
    'Authors'  => 'authors',
    'Contact'  => 'contact',
);

$nav_content = '';
foreach ($pages_map as $label => $slug) {
    $page = get_page_by_path($slug);
    if ($page) {
        $nav_content .= '<!-- wp:navigation-link {"label":"' . $label . '","type":"page","id":' . $page->ID . ',"url":"/' . $slug . '/","kind":"post-type"} /-->';
        WP_CLI::log("  Nav link: $label -> /$slug/ (ID: {$page->ID})");
    }
}

// Find or create the wp_navigation post
$nav_posts = get_posts(array(
    'post_type'      => 'wp_navigation',
    'posts_per_page' => 1,
    'post_status'    => 'publish',
));

if ($nav_posts) {
    wp_update_post(array(
        'ID'           => $nav_posts[0]->ID,
        'post_content' => $nav_content,
    ));
    WP_CLI::log("  Updated navigation block (ID: {$nav_posts[0]->ID})");
} else {
    $nav_id = wp_insert_post(array(
        'post_title'   => 'Navigation',
        'post_content' => $nav_content,
        'post_type'    => 'wp_navigation',
        'post_status'  => 'publish',
    ));
    WP_CLI::log("  Created navigation block (ID: $nav_id)");
}

// =========================================================================
// 2. Create custom footer template part to override theme default
// =========================================================================
$footer_links_left = array(
    'Blog'    => '/blog/',
    'About'   => '/about-us/',
    'FAQs'    => '/faq/',
    'Authors' => '/authors/',
);
$footer_links_right = array(
    'Events'     => '/events/',
    'Shop'       => '/shop/',
    'Contact'    => '/contact/',
    'My Account' => '/my-account/',
);

$footer_nav_left = '';
foreach ($footer_links_left as $label => $url) {
    $footer_nav_left .= '<!-- wp:navigation-link {"label":"' . $label . '","url":"' . $url . '"} /-->';
}
$footer_nav_right = '';
foreach ($footer_links_right as $label => $url) {
    $footer_nav_right .= '<!-- wp:navigation-link {"label":"' . $label . '","url":"' . $url . '"} /-->';
}

$footer_content = '<!-- wp:group {"style":{"spacing":{"padding":{"top":"var:preset|spacing|60","bottom":"var:preset|spacing|50"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="padding-top:var(--wp--preset--spacing--60);padding-bottom:var(--wp--preset--spacing--50)">
    <!-- wp:group {"align":"wide","layout":{"type":"default"}} -->
    <div class="wp-block-group alignwide">
        <!-- wp:site-logo /-->
        <!-- wp:group {"align":"full","layout":{"type":"flex","flexWrap":"wrap","justifyContent":"space-between","verticalAlignment":"top"}} -->
        <div class="wp-block-group alignfull">
            <!-- wp:columns -->
            <div class="wp-block-columns">
                <!-- wp:column {"width":"100%"} -->
                <div class="wp-block-column" style="flex-basis:100%"><!-- wp:site-title {"level":2} /-->
                <!-- wp:site-tagline /-->
                </div>
                <!-- /wp:column -->
                <!-- wp:column {"width":""} -->
                <div class="wp-block-column">
                    <!-- wp:spacer {"height":"var:preset|spacing|40","width":"0px"} -->
                    <div style="height:var(--wp--preset--spacing--40);width:0px" aria-hidden="true" class="wp-block-spacer"></div>
                    <!-- /wp:spacer -->
                </div>
                <!-- /wp:column -->
            </div>
            <!-- /wp:columns -->
            <!-- wp:group {"style":{"spacing":{"blockGap":"var:preset|spacing|80"}},"layout":{"type":"flex","flexWrap":"wrap","verticalAlignment":"top","justifyContent":"space-between"}} -->
            <div class="wp-block-group">
                <!-- wp:navigation {"overlayMenu":"never","layout":{"type":"flex","orientation":"vertical"}} -->
                    ' . $footer_nav_left . '
                <!-- /wp:navigation -->
                <!-- wp:navigation {"overlayMenu":"never","layout":{"type":"flex","orientation":"vertical"}} -->
                    ' . $footer_nav_right . '
                <!-- /wp:navigation -->
            </div>
            <!-- /wp:group -->
        </div>
        <!-- /wp:group -->
        <!-- wp:spacer {"height":"var:preset|spacing|70"} -->
        <div style="height:var(--wp--preset--spacing--70)" aria-hidden="true" class="wp-block-spacer"></div>
        <!-- /wp:spacer -->
        <!-- wp:group {"align":"full","style":{"spacing":{"blockGap":"var:preset|spacing|20"}},"layout":{"type":"flex","flexWrap":"wrap","justifyContent":"space-between"}} -->
        <div class="wp-block-group alignfull">
            <!-- wp:paragraph {"fontSize":"small"} -->
            <p class="has-small-font-size">TechGear Pro</p>
            <!-- /wp:paragraph -->
            <!-- wp:paragraph {"fontSize":"small"} -->
            <p class="has-small-font-size">Powered by <a href="https://wordpress.org" rel="nofollow">WordPress</a></p>
            <!-- /wp:paragraph -->
        </div>
        <!-- /wp:group -->
    </div>
    <!-- /wp:group -->
</div>
<!-- /wp:group -->';

// Check if a custom footer template part already exists in DB
$existing = get_posts(array(
    'post_type'      => 'wp_template_part',
    'name'           => 'footer',
    'posts_per_page' => 1,
    'post_status'    => 'any',
));

if ($existing) {
    wp_update_post(array(
        'ID'           => $existing[0]->ID,
        'post_content' => $footer_content,
    ));
    WP_CLI::log("  Updated footer template part (ID: {$existing[0]->ID})");
} else {
    $footer_id = wp_insert_post(array(
        'post_title'   => 'Footer',
        'post_name'    => 'footer',
        'post_type'    => 'wp_template_part',
        'post_status'  => 'publish',
        'post_content' => $footer_content,
    ));
    if ($footer_id) {
        wp_set_object_terms($footer_id, 'twentytwentyfive', 'wp_theme');
        WP_CLI::log("  Created footer template part (ID: $footer_id)");
    }
}

WP_CLI::success("Navigation and footer configured");
NAV_PHP

    print_status "Navigation and footer configured"
}

create_sample_orders() {
    print_info "Creating sample orders..."

    # Use WooCommerce PHP API directly (works with HPOS custom order tables)
    wp eval-file - --allow-root <<'ORDERS_PHP'
<?php
$products = wc_get_products(array('limit' => 10, 'status' => 'publish'));
if (empty($products)) {
    WP_CLI::warning("No products found, skipping order creation");
    exit(0);
}

$order_data = array(
    array(
        'status' => 'completed',
        'billing' => array(
            'first_name' => 'Alice', 'last_name' => 'Anderson',
            'email' => 'alice@example.com', 'address_1' => '123 Main St',
            'city' => 'San Francisco', 'state' => 'CA', 'postcode' => '94102', 'country' => 'US',
        ),
        'product_index' => 0, 'quantity' => 1,
    ),
    array(
        'status' => 'processing',
        'billing' => array(
            'first_name' => 'Bob', 'last_name' => 'Brown',
            'email' => 'bob@example.com', 'address_1' => '456 Oak Ave',
            'city' => 'Los Angeles', 'state' => 'CA', 'postcode' => '90001', 'country' => 'US',
        ),
        'note' => 'Please deliver between 9-5, use code #1234 at gate',
        'product_index' => 1, 'quantity' => 2,
    ),
    array(
        'status' => 'on-hold',
        'billing' => array(
            'first_name' => 'Carol', 'last_name' => 'Davis',
            'email' => 'carol@example.com', 'address_1' => '789 Pine Rd',
            'city' => 'Seattle', 'state' => 'WA', 'postcode' => '98101', 'country' => 'US',
        ),
        'product_index' => 2, 'quantity' => 1,
    ),
    array(
        'status' => 'failed',
        'billing' => array(
            'first_name' => 'David', 'last_name' => 'Evans',
            'email' => 'david@example.com', 'address_1' => '321 Elm St',
            'city' => 'Portland', 'state' => 'OR', 'postcode' => '97201', 'country' => 'US',
        ),
        'note' => 'Payment error: <script>alert(\'test\')</script> - please contact support',
        'product_index' => 3, 'quantity' => 1,
    ),
    array(
        'status' => 'completed',
        'billing' => array(
            'first_name' => 'Eve', 'last_name' => 'Foster',
            'email' => 'eve@example.com', 'address_1' => '555 Maple Dr',
            'city' => 'Austin', 'state' => 'TX', 'postcode' => '73301', 'country' => 'US',
        ),
        'product_index' => 4, 'quantity' => 3,
    ),
);

$created = 0;
foreach ($order_data as $od) {
    $order = wc_create_order();
    $order->set_billing_first_name($od['billing']['first_name']);
    $order->set_billing_last_name($od['billing']['last_name']);
    $order->set_billing_email($od['billing']['email']);
    $order->set_billing_address_1($od['billing']['address_1']);
    $order->set_billing_city($od['billing']['city']);
    $order->set_billing_state($od['billing']['state']);
    $order->set_billing_postcode($od['billing']['postcode']);
    $order->set_billing_country($od['billing']['country']);

    // Link to customer account if it exists
    $user = get_user_by('email', $od['billing']['email']);
    if ($user) $order->set_customer_id($user->ID);

    $pi = min($od['product_index'], count($products) - 1);
    $order->add_product($products[$pi], $od['quantity']);

    if (!empty($od['note'])) $order->set_customer_note($od['note']);

    $order->calculate_totals();
    $order->set_status($od['status']);
    $order->save();
    $created++;
    WP_CLI::log("  Created order #{$order->get_id()} - {$od['status']}");
}
WP_CLI::success("Created $created sample orders");
ORDERS_PHP

    print_status "Sample orders created"
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
    echo "  ✓ 50+ products with images and special characters in names"
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
    "add_product_images"
    "create_product_categories"
    "create_users"
    "create_blog_posts"
    "create_comments"
    "create_pages"
    "configure_contact_forms"
    "configure_site_settings"
    "configure_navigation"
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

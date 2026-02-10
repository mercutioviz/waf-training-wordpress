#!/bin/bash

# Product Images - Downloads stock photos from Unsplash and attaches to WooCommerce products
# Can be run standalone or called from setup.sh as add_product_images()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

add_product_images() {
    print_info "Adding product images from Unsplash..."

    # Map: product_id|filename|unsplash_photo_url
    # Images selected to match each product type
    local PRODUCT_IMAGES=(
        # Laptops
        "22|macbook-pro|https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=800&q=80"
        "23|dell-xps-13|https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=800&q=80"
        "24|thinkpad-x1-carbon|https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=800&q=80"

        # Mice
        "25|gaming-mouse|https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=800&q=80"
        "26|logitech-mx-master|https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=800&q=80"

        # Cables & Adapters
        "27|usb-c-adapter|https://images.unsplash.com/photo-1625842268584-8f3296236761?w=800&q=80"
        "28|thunderbolt-cable|https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800&q=80"
        "29|hdmi-cable|https://images.unsplash.com/photo-1605236453806-6ff36851218e?w=800&q=80"
        "56|displayport-cable|https://images.unsplash.com/photo-1625842268584-8f3296236761?w=800&q=80"
        "57|usb-c-hdmi-adapter|https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800&q=80"

        # Hubs & Docks
        "30|usb-hub|https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6?w=800&q=80"
        "31|docking-station|https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6?w=800&q=80"

        # Keyboards
        "32|mechanical-keyboard|https://images.unsplash.com/photo-1618384887929-16ec33fab9ef?w=800&q=80"
        "33|keychron-k8|https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800&q=80"

        # Monitors
        "34|4k-ips-monitor|https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800&q=80"
        "35|ultrawide-gaming-monitor|https://images.unsplash.com/photo-1593640408182-31c70c8268f5?w=800&q=80"

        # Webcam & Microphone
        "36|4k-webcam|https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=800&q=80"
        "37|usb-condenser-mic|https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=800&q=80"

        # Headset
        "38|noise-canceling-headset|https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&q=80"

        # Tablets
        "39|ipad-pro|https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=800&q=80"
        "68|android-tablet|https://images.unsplash.com/photo-1561154464-82e9adf32764?w=800&q=80"

        # Stylus
        "40|surface-pen|https://images.unsplash.com/photo-1585790050230-5dd28404ccb9?w=800&q=80"

        # Chargers
        "41|gan-usb-c-charger|https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=800&q=80"
        "42|dual-usb-c-charger|https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=800&q=80"

        # Power Bank
        "43|power-bank|https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=800&q=80"

        # Smart Home
        "44|smart-led-bulbs|https://images.unsplash.com/photo-1558089687-f282ffcbc126?w=800&q=80"
        "45|smart-plug|https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=800&q=80"
        "46|smart-thermostat|https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=800&q=80"

        # Networking
        "47|mesh-router|https://images.unsplash.com/photo-1606904825846-647eb07f5be2?w=800&q=80"
        "48|ethernet-switch|https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&q=80"

        # Storage
        "49|nas-storage|https://images.unsplash.com/photo-1597852074816-d933c7d2b988?w=800&q=80"
        "50|nvme-ssd|https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800&q=80"
        "51|portable-ssd|https://images.unsplash.com/photo-1531492746076-161ca9bcad58?w=800&q=80"

        # Accessories
        "52|tech-backpack|https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800&q=80"
        "53|laptop-stand|https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?w=800&q=80"
        "54|led-desk-lamp|https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=800&q=80"
        "55|screen-cleaning-kit|https://images.unsplash.com/photo-1563206767-5b18f218e8de?w=800&q=80"
        "59|bluetooth-speaker|https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=800&q=80"
        "60|ring-light|https://images.unsplash.com/photo-1598550476439-6847785fcea6?w=800&q=80"
        "69|e-reader|https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&q=80"

        # Gaming
        "58|wireless-controller|https://images.unsplash.com/photo-1592840496694-26d035b52b48?w=800&q=80"

        # PC Components
        "61|ddr5-ram|https://images.unsplash.com/photo-1562976540-1502c2145186?w=800&q=80"
        "62|modular-psu|https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=800&q=80"
        "63|atx-case|https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=800&q=80"
        "64|aio-liquid-cooler|https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800&q=80"
        "65|rgb-case-fans|https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800&q=80"
        "66|thermal-paste|https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80"
        "67|pc-toolkit|https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&q=80"
        "70|rtx-4070-gpu|https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800&q=80"
    )

    local imported=0
    local skipped=0
    local failed=0
    local total=${#PRODUCT_IMAGES[@]}

    for entry in "${PRODUCT_IMAGES[@]}"; do
        IFS='|' read -r PRODUCT_ID FILENAME IMAGE_URL <<< "$entry"

        # Check if product already has a featured image
        EXISTING_THUMB=$(wp post meta get "$PRODUCT_ID" _thumbnail_id --allow-root 2>/dev/null)
        if [ ! -z "$EXISTING_THUMB" ] && [ "$EXISTING_THUMB" != "" ]; then
            print_info "  Skipping product $PRODUCT_ID ($FILENAME) - already has featured image"
            ((skipped++))
            continue
        fi

        # Download image
        curl -sL "$IMAGE_URL" -o "/tmp/${FILENAME}.jpg"
        if [ $? -ne 0 ] || [ ! -s "/tmp/${FILENAME}.jpg" ]; then
            print_error "  Failed to download image for $FILENAME (product $PRODUCT_ID)"
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
            print_status "  [$imported/$total] Product $PRODUCT_ID ($FILENAME) -> attachment $ATTACHMENT_ID"
        else
            ((failed++))
            print_error "  Failed to set featured image for product $PRODUCT_ID"
        fi

        rm -f "/tmp/${FILENAME}.jpg"
    done

    print_status "Product images complete — Imported: $imported | Skipped: $skipped | Failed: $failed"
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    add_product_images
fi
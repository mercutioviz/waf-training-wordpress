#!/bin/bash
# Import blog posts and create pages

set -e

source /tmp/scripts/utils/logging.sh
source /tmp/scripts/utils/wp-cli-helpers.sh

log_info "Creating content (posts and pages)..."

# Create blog categories
log_info "Creating blog categories..."

BLOG_CATEGORIES=(
    "Hiking Tips:hiking-tips"
    "Gear Reviews:gear-reviews"
    "Trail Guides:trail-guides"
    "Camping:camping"
    "Safety:safety"
)

for cat_data in "${BLOG_CATEGORIES[@]}"; do
    IFS=':' read -r cat_name cat_slug <<< "${cat_data}"
    
    # Check if category exists (suppress errors)
    if ! wp_cli term get category "${cat_slug}" >/dev/null 2>&1; then
        # Create category (don't fail if it exists)
        wp_cli term create category "${cat_name}" --slug="${cat_slug}" 2>/dev/null || log_debug "Category already exists: ${cat_name}"
        log_info "Created category: ${cat_name}"
    else
        log_debug "Category already exists: ${cat_name}"
    fi
done

# Create blog posts
log_info "Creating blog posts..."

declare -a POSTS=(
    "10 Essential Items for Your First Hiking Trip|hiking-tips|Looking to hit the trails for the first time? Here's a comprehensive guide to the essential gear you'll need. From proper footwear to navigation tools, we cover everything a beginner hiker should pack. Learn about layering clothing, choosing the right backpack, and why a first aid kit is non-negotiable. We'll also discuss the importance of bringing enough water, high-energy snacks, and a reliable map and compass even if you're using GPS."
    "How to Choose the Right Backpack for Multi-Day Treks|gear-reviews|Selecting a backpack for multi-day trips requires careful consideration of capacity, fit, and features. This guide walks you through measuring torso length, understanding hip belt importance, and evaluating suspension systems. We also cover the difference between top-loading and panel-loading designs, the pros and cons of internal vs external frames, and how to properly fit and adjust your pack for maximum comfort on long trails."
    "Best Trails in Rocky Mountain National Park|trail-guides|Rocky Mountain National Park offers some of the most stunning hiking in Colorado. We've compiled our top 10 favorite trails, ranging from easy lakeside walks to challenging alpine ascents. Each trail includes difficulty rating, distance, elevation gain, and the best time of year to visit. Don't miss the spectacular views from Trail Ridge Road or the pristine lakes on the high country trails."
    "Winter Camping: A Beginner's Guide|camping|Winter camping can be an incredibly rewarding experience, but it requires special preparation and gear. Learn about four-season tents, proper sleeping bag ratings, and how to stay warm in freezing temperatures. We also cover winter-specific safety concerns like hypothermia and avalanche awareness, proper clothing layering systems, and how to manage condensation inside your tent during cold nights."
    "Trail Safety: Wildlife Encounters 101|safety|Understanding how to react during wildlife encounters can save your life. This comprehensive guide covers what to do if you meet bears, mountain lions, moose, and other wild animals on the trail. We include tips on food storage, making noise while hiking, and carrying bear spray. Learn the difference between black bear and grizzly bear behavior, and why you should never run from a predator."
    "Ultralight Backpacking: Cut Your Pack Weight in Half|gear-reviews|Going ultralight doesn't mean sacrificing comfort or safety. Learn the principles of ultralight backpacking and discover which gear swaps make the biggest impact. We discuss the base weight concept, multi-use items, and which luxuries are worth keeping. Find out how to evaluate every item in your pack and make smart choices about what stays and what goes."
    "Leave No Trace: 7 Principles Every Hiker Should Know|safety|Preserving our wilderness areas for future generations starts with following Leave No Trace principles. This article breaks down all seven principles with practical examples of how to minimize your impact on the trail. From proper waste disposal to respecting wildlife, learn how to be a responsible outdoor enthusiast."
    "Best Hiking Boots of 2024: Our Top Picks|gear-reviews|After testing dozens of hiking boots on trails across the country, we've narrowed down our favorites. This comprehensive review covers boots for day hiking, backpacking, and mountaineering. We evaluate comfort, durability, waterproofing, and traction to help you find the perfect fit for your adventures."
    "Meal Planning for Multi-Day Backpacking Trips|backpacking|Proper nutrition is crucial for maintaining energy on long backpacking trips. Learn how to calculate calorie needs, choose lightweight and nutritious foods, and plan meals that are easy to prepare on the trail. We share our favorite dehydrated meal recipes and tips for packing a bear canister efficiently."
    "How to Navigate with Map and Compass|hiking-tips|GPS devices are great, but knowing how to navigate with traditional tools is an essential wilderness skill. This step-by-step tutorial teaches you how to read topographic maps, take bearings with a compass, and triangulate your position. Practice these skills before you need them in an emergency situation."
    "The Best Day Hikes Near Denver|trail-guides|Living in Denver means having world-class hiking right in your backyard. We've rounded up 15 fantastic day hikes within an hour of the city, from easy family-friendly walks to challenging summit climbs. Each hike includes detailed directions, parking information, and what to expect on the trail."
    "Tent Care and Maintenance: Make Your Shelter Last|camping|A quality tent is an investment worth protecting. Learn proper setup techniques, cleaning methods, and storage tips to extend the life of your tent. We cover how to repair small tears, maintain waterproofing, and prevent mold and mildew during off-season storage."
    "Photography Tips for Outdoor Adventures|hiking-tips|Capture stunning photos of your outdoor adventures with these expert tips. From golden hour lighting to composition techniques, learn how to make your trail photos stand out. We also discuss essential camera gear for backpackers and how to protect electronics in harsh conditions."
    "Alpine Climbing: Taking Your Skills to New Heights|climbing|Ready to transition from rock climbing to alpine routes? This guide covers the additional skills and gear needed for high-altitude climbing. Learn about glacier travel, crevasse rescue, and how weather patterns differ in the alpine environment."
    "Hammock Camping vs Traditional Tents|camping|Hammock camping has grown in popularity, but is it right for you? We compare the pros and cons of hammocks versus tents, including weight, versatility, comfort, and weather protection. Discover which option works best for different environments and camping styles."
)

CREATED=0
TOTAL=${#POSTS[@]}

for post_data in "${POSTS[@]}"; do
    IFS='|' read -r post_title post_cat post_content <<< "${post_data}"
    
    CREATED=$((CREATED + 1))
    show_progress ${CREATED} ${TOTAL} "Creating blog posts"
    
    # Get category ID
    CAT_TERM=$(wp_cli term get category "${post_cat}" --field=term_id 2>/dev/null || echo "1")
    
    # Create post
    POST_ID=$(wp_cli post create \
        --post_type=post \
        --post_title="${post_title}" \
        --post_content="${post_content}" \
        --post_status=publish \
        --post_category="${CAT_TERM}" \
        --post_author=1 \
        --porcelain) || true
    
    # Set random date in the past (last 6 months)
    RANDOM_DAYS=$((RANDOM % 180))
    wp_cli post update ${POST_ID} --post_date="$(date -d "${RANDOM_DAYS} days ago" '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
    
    log_debug "Created post: ${post_title}"
done

echo "" # New line after progress

# Create important pages
log_info "Creating pages..."

# About page
ABOUT_CONTENT="<h2>Welcome to Summit Outfitters</h2>
<p>For over 20 years, Summit Outfitters has been providing outdoor enthusiasts with premium gear and expert advice. Our passion for the outdoors drives everything we do, from carefully curating our product selection to sharing our knowledge through guides and tutorials.</p>

<h3>Our Story</h3>
<p>Founded in 2003 by avid climbers and backpackers, Summit Outfitters started as a small shop in Denver, Colorado. Today, we serve customers around the world through our online store while maintaining our commitment to quality, sustainability, and customer service.</p>

<h3>Our Mission</h3>
<p>We believe that everyone should have access to reliable gear and the knowledge to use it safely. Whether you're planning your first day hike or your next alpine expedition, we're here to help you prepare for your adventure.</p>

<h3>Why Choose Us</h3>
<ul>
<li>Expert staff with real outdoor experience</li>
<li>Carefully selected products from trusted brands</li>
<li>Comprehensive guides and educational content</li>
<li>Commitment to environmental sustainability</li>
<li>30-day satisfaction guarantee</li>
</ul>

<h3>Get in Touch</h3>
<p>Have questions? Our team is here to help. Contact us through our contact form or visit our store in Denver.</p>"

create_page_if_not_exists "About Us" "${ABOUT_CONTENT}" "publish"

# Contact page with form
CONTACT_CONTENT="<h2>Contact Summit Outfitters</h2>
<p>We'd love to hear from you! Whether you have questions about products, need gear advice, or just want to share your latest adventure, reach out to us.</p>

<h3>Store Location</h3>
<p><strong>Summit Outfitters</strong>

1234 Mountain View Drive, Suite 100

Denver, CO 80202</p>

<h3>Hours</h3>
<p>Monday - Friday: 9:00 AM - 7:00 PM

Saturday: 10:00 AM - 6:00 PM

Sunday: 11:00 AM - 5:00 PM</p>

<h3>Phone</h3>
<p>(303) 555-0123</p>

<h3>Email</h3>
<p>info@summitoutfitters.com</p>

<h3>Send Us a Message</h3>
[contact-form-7 id=\"1\" title=\"Contact form 1\"]"

create_page_if_not_exists "Contact" "${CONTACT_CONTENT}" "publish"

# Shipping & Returns
SHIPPING_CONTENT="<h2>Shipping Information</h2>

<h3>Shipping Methods</h3>
<p>We offer several shipping options to get your gear to you quickly:</p>
<ul>
<li><strong>Standard Shipping (5-7 business days):</strong> \$5.99</li>
<li><strong>Express Shipping (2-3 business days):</strong> \$15.99</li>
<li><strong>Free Shipping:</strong> On orders over \$75</li>
</ul>

<h3>Processing Time</h3>
<p>Orders are typically processed within 1-2 business days. You'll receive a tracking number via email once your order ships.</p>

<h3>International Shipping</h3>
<p>We ship to most countries worldwide. International shipping costs are calculated at checkout based on destination and package weight.</p>

<h2>Returns & Exchanges</h2>

<h3>30-Day Satisfaction Guarantee</h3>
<p>If you're not completely satisfied with your purchase, return it within 30 days for a full refund or exchange. Items must be unused and in original packaging.</p>

<h3>How to Return</h3>
<ol>
<li>Contact us at returns@summitoutfitters.com to initiate a return</li>
<li>We'll provide a return authorization number and shipping label</li>
<li>Pack items securely in original packaging</li>
<li>Ship the package using the provided label</li>
<li>Refunds are processed within 5-7 business days of receiving your return</li>
</ol>

<h3>Warranty Information</h3>
<p>All products are covered by manufacturer warranties. We'll help facilitate warranty claims and repairs. Contact us for assistance.</p>"

create_page_if_not_exists "Shipping & Returns" "${SHIPPING_CONTENT}" "publish"

# FAQ page
FAQ_CONTENT="<h2>Frequently Asked Questions</h2>

<h3>Ordering & Payment</h3>
<p><strong>What payment methods do you accept?</strong>

We accept all major credit cards (Visa, MasterCard, American Express, Discover), PayPal, and direct bank transfers.</p>

<p><strong>Is my payment information secure?</strong>

Yes. We use industry-standard SSL encryption to protect your payment information.</p>

<p><strong>Can I modify or cancel my order?</strong>

Contact us immediately at orders@summitoutfitters.com. If your order hasn't shipped yet, we can modify or cancel it.</p>

<h3>Shipping</h3>
<p><strong>Do you ship internationally?</strong>

Yes, we ship to most countries worldwide. Shipping costs and delivery times vary by destination.</p>

<p><strong>How can I track my order?</strong>

You'll receive a tracking number via email once your order ships. Use this to track your package.</p>

<h3>Products & Sizing</h3>
<p><strong>How do I choose the right size?</strong>

Each product page includes detailed sizing information. If you're between sizes, we generally recommend sizing up for comfort.</p>

<p><strong>Are your products authentic?</strong>

Absolutely. We only sell genuine products from authorized manufacturers.</p>

<h3>Returns & Exchanges</h3>
<p><strong>What is your return policy?</strong>

We offer a 30-day satisfaction guarantee. Items must be unused and in original packaging.</p>

<p><strong>Who pays for return shipping?</strong>

We provide prepaid return labels for defective items. For other returns, customers are responsible for return shipping costs.</p>"

create_page_if_not_exists "FAQ" "${FAQ_CONTENT}" "publish"

log_success "Content creation complete"

# Display content counts
POST_COUNT=$(wp_cli post list --post_type=post --format=count)
PAGE_COUNT=$(wp_cli post list --post_type=page --format=count)
log_info "Total posts: ${POST_COUNT}"
log_info "Total pages: ${PAGE_COUNT}"

exit 0

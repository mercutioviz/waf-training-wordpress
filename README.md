# TechGear Pro - WordPress WAF Training Environment

A complete WordPress + WooCommerce environment designed for training security analysts on Web Application Firewall (WAF) false positive detection and tuning.

## Overview

This Docker-based setup creates a realistic e-commerce site with intentionally crafted content that generates WAF false positives. Perfect for training teams to differentiate between legitimate traffic patterns and actual attacks.

## Features

### Realistic E-Commerce Site
- **50+ tech products** with names containing special characters (`15" MacBook Pro`, `O'Reilly's Gaming Mouse`, `USB-C to USB-A (3-Pack)`)
- **WooCommerce** fully configured with categories, variable products, and pricing
- **Sample orders** with various statuses and customer notes containing suspicious patterns
- **Product reviews and comments** with technical content, error messages, and code snippets

### False Positive Generators
- **Contact forms** accepting error messages, code snippets, and technical details
- **Search functionality** that accepts any input (including SQL-like queries)
- **File uploads** for support tickets and product inquiries
- **Rich content** with HTML entities, quotes, apostrophes, and special characters
- **Customer notes** with delivery instructions containing special characters
- **User comments** discussing technical issues with paths, config files, and error messages

### Installed Plugins
- WooCommerce - E-commerce platform
- Contact Form 7 - Multiple forms with file upload
- WPForms Lite - Alternative form builder
- Wordfence Security - Security plugin (generates its own traffic)
- Limit Login Attempts - Brute force protection
- Yoast SEO - SEO optimization (heavy admin operations)
- Jetpack - External API calls and features
- Advanced Custom Fields - Custom product fields
- Elementor - Page builder
- Query Monitor - Development/debugging tool
- User Switching - Quick user role changes
- FakerPress - Content generation

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- At least 4GB of available RAM
- Ports 8080 and 8081 available

### Installation

1. **Clone or download this directory**
   ```bash
   cd wordpress-waf-training
   ```

2. **Start the containers**
   ```bash
   docker-compose up -d
   ```

3. **Wait for WordPress to initialize** (about 30-60 seconds)
   ```bash
   docker-compose logs -f wordpress
   # Wait for "ready to handle connections" message
   ```

4. **Run the setup script**
   ```bash
   docker-compose exec wpcli bash /setup.sh
   ```
   This will take 5-10 minutes to complete. It will:
   - Install WordPress
   - Install and configure all plugins
   - Import 50 products
   - Create user accounts
   - Generate blog posts and comments
   - Create sample orders
   - Configure contact forms

5. **Access your site**
   - **WordPress site**: http://localhost:8080
   - **Admin panel**: http://localhost:8080/wp-admin
   - **phpMyAdmin**: http://localhost:8081

### Default Credentials

**WordPress Admin**
- Username: `admin`
- Password: `TechGear2024!`

**Additional Test Users**
- Administrators: `manager1@techgearpro.local` / `Manager123!`
- Shop Manager: `shopmanager@techgearpro.local` / `Shop123!`
- Customer: `alice@example.com` / `Customer123!`

**Database (phpMyAdmin)**
- Username: `root`
- Password: `root_pass`

## WAF Training Scenarios

### Scenario 1: Product Search False Positives
**Objective**: Identify SQLi false positives from legitimate searches

**Steps**:
1. Navigate to the shop page
2. Search for: `O'Reilly's`
3. Search for: `15" laptop`
4. Search for: `USB-C to USB-A`
5. Review WAF logs for SQL injection alerts

**Expected**: False positives due to apostrophes, quotes, and special characters

### Scenario 2: Contact Form Submissions
**Objective**: Differentiate between legitimate technical support and XSS attacks

**Steps**:
1. Go to Contact page
2. Submit Technical Support form with:
   ```
   I'm getting error: SELECT * FROM products WHERE id=123
   My config file at /etc/myapp/config.conf shows:
   <configuration>
     <setting name="debug">true</setting>
   </configuration>
   ```
3. Review WAF logs for SQLi and XSS alerts

**Expected**: Multiple false positives (SQLi from SELECT, XSS from XML tags, path traversal from /etc/)

### Scenario 3: Product Reviews
**Objective**: Identify false positives in user-generated content

**Steps**:
1. Navigate to any product
2. Add review: "Great cable! Fixed my 'cannot connect' error. Works with devices at 192.168.1.1"
3. Review WAF logs

**Expected**: False positives from error messages, IP addresses, and quotes

### Scenario 4: Order Processing
**Objective**: Understand false positives in checkout flow

**Steps**:
1. Add products to cart
2. Proceed to checkout
3. In order notes: "Please deliver between 9-5, code: #1234"
4. Complete checkout
5. Review WAF logs

**Expected**: Potential false positives from special characters in notes

### Scenario 5: Admin Operations
**Objective**: Identify legitimate admin traffic patterns

**Steps**:
1. Login as admin
2. Bulk edit products
3. Update plugin settings
4. Modify theme customization
5. Review WAF logs

**Expected**: High volume of POST requests, file operations, may trigger rate limiting or suspicious activity alerts

### Scenario 6: API and REST Requests
**Objective**: Understand WordPress REST API traffic

**Steps**:
1. Enable Query Monitor plugin
2. Navigate through site
3. Observe REST API calls in Query Monitor
4. Review WAF logs for API endpoint access

**Expected**: Legitimate but frequent API calls that might trigger rate limits

## Customization

### Adding More Products
1. Edit `products.csv`
2. Restart containers: `docker-compose restart`
3. Run: `docker-compose exec wpcli wp wc product import /products.csv --user=admin --allow-root`

### Creating Additional Forms
1. Login to WordPress admin
2. Go to Contact > Contact Forms
3. Add new form with fields designed to trigger WAF rules

### Generating More Content
1. Access WP-CLI: `docker-compose exec wpcli wp shell --allow-root`
2. Use FakerPress or WP-CLI commands to generate posts, users, comments

### Modifying False Positive Triggers
Edit the `setup.sh` script to customize:
- Comment content
- Customer notes
- Product descriptions
- Form field placeholders

## Integrating with Your WAF

### Method 1: Direct Proxy
Configure your WAF to proxy traffic to `http://localhost:8080`

Example nginx WAF config:
```nginx
upstream wordpress {
    server localhost:8080;
}

server {
    listen 80;
    server_name waf-training.local;
    
    location / {
        proxy_pass http://wordpress;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Method 2: Docker Network
1. Modify `docker-compose.yml` to add your WAF container
2. Place WAF on same network as nginx
3. Route traffic through WAF before reaching nginx

### Method 3: External WAF
1. Expose nginx on different port: `ports: - "80:80"`
2. Configure external WAF to forward to your Docker host

## Training Exercises

### Exercise 1: Baseline Creation
**Duration**: 30 minutes

1. Enable WAF in monitoring mode
2. Perform normal user activities:
   - Browse products
   - Submit contact form with legitimate inquiry
   - Create user account
   - Complete checkout
3. Review logs to understand legitimate traffic patterns
4. Document common false positive triggers

### Exercise 2: Tuning Rules
**Duration**: 1 hour

1. Enable WAF in blocking mode with default rules
2. Attempt all legitimate scenarios from Scenario 1-6
3. For each blocked request:
   - Analyze the WAF rule triggered
   - Determine if it's a false positive
   - Create rule exception or modify threshold
   - Document the tuning decision
4. Re-test to verify fixes don't break security

### Exercise 3: Attack vs. Legitimate Traffic
**Duration**: 1 hour

1. Generate legitimate traffic (product searches, form submissions)
2. Mix in actual attack attempts:
   - `' OR 1=1--` in search
   - `<script>alert(document.cookie)</script>` in comments
   - `../../etc/passwd` in file uploads
3. Review mixed logs
4. Practice identifying which are attacks vs. false positives

### Exercise 4: Advanced Tuning
**Duration**: 2 hours

1. Focus on specific rule categories:
   - SQL injection rules
   - XSS rules
   - Path traversal rules
   - Rate limiting rules
2. For each category:
   - Test with edge cases
   - Find acceptable thresholds
   - Document exceptions
   - Create custom rules if needed

## Troubleshooting

### WordPress not accessible
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs wordpress
docker-compose logs nginx

# Restart containers
docker-compose restart
```

### Setup script fails
```bash
# Check WP-CLI container
docker-compose logs wpcli

# Manually run WP-CLI commands
docker-compose exec wpcli wp --info --allow-root

# Re-run setup
docker-compose exec wpcli bash /setup.sh
```

### Products not importing
```bash
# Manually import products
docker-compose exec wpcli wp wc product import /products.csv --user=admin --allow-root

# Check product count
docker-compose exec wpcli wp wc product list --allow-root
```

### Plugin activation issues
```bash
# List installed plugins
docker-compose exec wpcli wp plugin list --allow-root

# Activate specific plugin
docker-compose exec wpcli wp plugin activate woocommerce --allow-root
```

## Maintenance

### Reset to Clean State
```bash
# Stop containers
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker-compose down -v

# Restart and re-run setup
docker-compose up -d
docker-compose exec wpcli bash /setup.sh
```

### Backup Data
```bash
# Backup WordPress files
docker cp techgear_wordpress:/var/www/html ./backup-wp

# Export database
docker-compose exec db mysqldump -u wordpress -pwordpress_pass wordpress > backup-db.sql
```

### Restore Data
```bash
# Restore WordPress files
docker cp ./backup-wp/. techgear_wordpress:/var/www/html

# Import database
docker-compose exec -T db mysql -u wordpress -pwordpress_pass wordpress < backup-db.sql
```

### Update WordPress and Plugins
```bash
# Update WordPress core
docker-compose exec wpcli wp core update --allow-root

# Update all plugins
docker-compose exec wpcli wp plugin update --all --allow-root

# Update themes
docker-compose exec wpcli wp theme update --all --allow-root
```

## Logs and Monitoring

### Application Logs
- WordPress debug log: `./logs/debug.log` (if enabled)
- nginx access log: `./logs/nginx/access.log`
- nginx error log: `./logs/nginx/error.log`

### Viewing Logs in Real-Time
```bash
# WordPress logs
docker-compose logs -f wordpress

# nginx logs
docker-compose logs -f nginx

# Database logs
docker-compose logs -f db

# All logs
docker-compose logs -f
```

### Query Monitor
Access http://localhost:8080/wp-admin and enable Query Monitor plugin to see:
- Database queries
- HTTP requests
- PHP errors
- Hooks and actions
- Environment info

## Security Notes

**⚠️ This is a TRAINING environment - DO NOT expose to the internet!**

- Default passwords are intentionally weak for training purposes
- Debug mode is enabled
- Security plugins are configured with minimal restrictions
- No HTTPS/TLS (intentional for simplified setup)
- Use in isolated lab environment only

## Architecture

```
┌─────────────────┐
│   nginx:alpine  │  Port 8080 (HTTP)
│  (Web Server)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  wordpress:php  │
│  (Application)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   mysql:8.0     │
│   (Database)    │
└─────────────────┘

Supporting Containers:
├── phpmyadmin (Port 8081)
└── wpcli (WP-CLI for management)
```

## File Structure

```
wordpress-waf-training/
├── docker-compose.yml      # Container orchestration
├── nginx.conf             # nginx web server configuration
├── setup.sh              # Automated setup script
├── products.csv          # 50 sample products
├── forms-config.json     # Contact form definitions
├── README.md            # This file
└── logs/               # Application logs (created at runtime)
    ├── nginx/
    │   ├── access.log
    │   └── error.log
    └── debug.log       # WordPress debug log
```

## Advanced Usage

### Custom WordPress Configuration
Edit environment variables in `docker-compose.yml`:
```yaml
environment:
  WORDPRESS_DEBUG: 1
  WORDPRESS_DEBUG_LOG: true
  WP_MEMORY_LIMIT: 256M
```

### Database Access
```bash
# MySQL CLI
docker-compose exec db mysql -u wordpress -pwordpress_pass wordpress

# Or use phpMyAdmin at http://localhost:8081
```

### WP-CLI Access
```bash
# Interactive shell
docker-compose exec wpcli wp shell --allow-root

# Run single command
docker-compose exec wpcli wp post list --allow-root

# Export all data
docker-compose exec wpcli wp export --allow-root
```

## Support and Feedback

This training environment is designed to help security analysts develop practical skills in WAF tuning. For questions or issues:

1. Check the Troubleshooting section
2. Review Docker logs
3. Verify all containers are running: `docker-compose ps`

## License

This training environment is provided as-is for educational purposes.

## Credits

Built with:
- WordPress
- WooCommerce
- Contact Form 7
- nginx
- MySQL
- Docker

---

**Happy WAF Training!** 🛡️

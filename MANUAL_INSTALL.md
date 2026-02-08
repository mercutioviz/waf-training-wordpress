# Manual WordPress Installation Guide

If the automated setup script isn't working, follow these steps to manually install WordPress.

## Step 1: Run Diagnostics

```bash
sudo bash diagnose-wordpress.sh
```

This will tell you exactly what's wrong. Read the output carefully.

## Step 2: Verify Containers Are Running

```bash
sudo docker compose ps
```

All containers should show "Up". If not:

```bash
sudo docker compose up -d
sudo docker compose logs -f wordpress
# Wait for "ready to handle connections" message
# Press Ctrl+C
```

## Step 3: Check Database Connection

```bash
# Test database from WordPress container
sudo docker compose exec wordpress php -r "
\$conn = mysqli_connect('db', 'wordpress', 'wordpress_pass', 'wordpress');
if (\$conn) {
    echo 'Database connection: SUCCESS\n';
    mysqli_close(\$conn);
} else {
    echo 'Database connection: FAILED - ' . mysqli_connect_error() . '\n';
}
"
```

If this fails:
- Wait longer (database might still be initializing)
- Check database logs: `sudo docker compose logs db`
- Restart database: `sudo docker compose restart db`

## Step 4: Verify WordPress Files Exist

```bash
# Check if WordPress core files are present
sudo docker compose exec wordpress ls -la /var/www/html/

# Should see files like:
# wp-config.php (or wp-config-sample.php)
# wp-load.php
# index.php
# wp-admin/
# wp-includes/
```

If files are missing:
```bash
# WordPress container might not have initialized
sudo docker compose restart wordpress
# Wait 60 seconds
sudo docker compose exec wordpress ls -la /var/www/html/
```

## Step 5: Check wp-config.php

```bash
# Verify wp-config.php exists
sudo docker compose exec wordpress test -f /var/www/html/wp-config.php && echo "EXISTS" || echo "MISSING"
```

If MISSING:
```bash
# Create wp-config.php from sample
sudo docker compose exec wordpress cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Update database credentials
sudo docker compose exec wordpress sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sudo docker compose exec wordpress sed -i "s/username_here/wordpress/" /var/www/html/wp-config.php
sudo docker compose exec wordpress sed -i "s/password_here/wordpress_pass/" /var/www/html/wp-config.php
sudo docker compose exec wordpress sed -i "s/localhost/db/" /var/www/html/wp-config.php
```

## Step 6: Install WordPress via WP-CLI

```bash
# Method 1: Simple installation
sudo docker compose exec wpcli wp core install \
  --url='http://localhost:8080' \
  --title='TechGear Pro' \
  --admin_user='admin' \
  --admin_password='TechGear2024!' \
  --admin_email='admin@techgearpro.local' \
  --skip-email \
  --allow-root
```

If you get errors, try:

```bash
# Method 2: Install without skip-email
sudo docker compose exec wpcli wp core install \
  --url='http://localhost:8080' \
  --title='TechGear Pro' \
  --admin_user='admin' \
  --admin_password='TechGear2024!' \
  --admin_email='admin@techgearpro.local' \
  --allow-root 2>&1 | tee install.log
```

## Step 7: Verify Installation

```bash
# Check if WordPress is installed
sudo docker compose exec wpcli wp core is-installed --allow-root && echo "INSTALLED" || echo "NOT INSTALLED"

# Check WordPress version
sudo docker compose exec wpcli wp core version --allow-root

# List database tables
sudo docker compose exec db mysql -u wordpress -pwordpress_pass wordpress -e "SHOW TABLES;"
```

## Step 8: Access WordPress

Open browser to: http://localhost:8080

**If you see the WordPress installation screen:**
- Complete it manually through the browser
- Use these credentials:
  - Site Title: TechGear Pro
  - Username: admin
  - Password: TechGear2024!
  - Email: admin@techgearpro.local

**If you see a blank page or error:**
- Check PHP logs: `sudo docker compose exec wordpress tail -f /var/log/php-fpm.log 2>/dev/null || echo "No PHP log"`
- Check nginx logs: `sudo docker compose logs nginx`
- Try accessing directly: `sudo docker compose exec wordpress curl -I http://localhost`

## Step 9: Install Plugins and Content

Once WordPress is installed and accessible:

```bash
# Install WooCommerce
sudo docker compose exec wpcli wp plugin install woocommerce --activate --allow-root

# Install other essential plugins
sudo docker compose exec wpcli wp plugin install contact-form-7 --activate --allow-root
sudo docker compose exec wpcli wp plugin install wpforms-lite --activate --allow-root

# Import products
sudo docker compose exec wpcli wp wc product import /products.csv --user=admin --allow-root
```

## Common Issues and Solutions

### Issue: "Error establishing database connection"

**Solution:**
```bash
# Wait for database to be ready
sudo docker compose logs db | grep "ready for connections"

# If not ready, restart and wait
sudo docker compose restart db
sleep 30
```

### Issue: "wp: command not found"

**Solution:**
```bash
# WP-CLI commands must run in the wpcli container
# Always use:
sudo docker compose exec wpcli wp <command> --allow-root

# NOT in the wordpress container:
# sudo docker compose exec wordpress wp <command>  # WRONG
```

### Issue: wp-config.php has wrong credentials

**Solution:**
```bash
# View current wp-config.php
sudo docker compose exec wordpress cat /var/www/html/wp-config.php | grep DB_

# Fix database name
sudo docker compose exec wordpress sed -i "s/define( 'DB_NAME', '.*' );/define( 'DB_NAME', 'wordpress' );/" /var/www/html/wp-config.php

# Fix username
sudo docker compose exec wordpress sed -i "s/define( 'DB_USER', '.*' );/define( 'DB_USER', 'wordpress' );/" /var/www/html/wp-config.php

# Fix password
sudo docker compose exec wordpress sed -i "s/define( 'DB_PASSWORD', '.*' );/define( 'DB_PASSWORD', 'wordpress_pass' );/" /var/www/html/wp-config.php

# Fix host
sudo docker compose exec wordpress sed -i "s/define( 'DB_HOST', '.*' );/define( 'DB_HOST', 'db' );/" /var/www/html/wp-config.php
```

### Issue: Permission denied errors

**Solution:**
```bash
# Fix file ownership
sudo docker compose exec wordpress chown -R www-data:www-data /var/www/html
```

### Issue: WordPress installed but can't login

**Solution:**
```bash
# Reset admin password
sudo docker compose exec wpcli wp user update admin \
  --user_pass='TechGear2024!' \
  --allow-root

# Or create new admin user
sudo docker compose exec wpcli wp user create admin2 admin2@techgearpro.local \
  --role=administrator \
  --user_pass='Admin123!' \
  --allow-root
```

## Complete Reset (Last Resort)

If nothing works, start completely fresh:

```bash
# Stop and remove everything
sudo docker compose down -v

# Clean Docker
sudo docker system prune -f

# Start fresh
sudo docker compose up -d

# Wait 2-3 minutes for full initialization
sleep 120

# Check logs to ensure everything is ready
sudo docker compose logs db | tail -20
sudo docker compose logs wordpress | tail -20

# Run diagnostics
sudo bash diagnose-wordpress.sh

# Try installation again
sudo docker compose exec wpcli wp core install \
  --url='http://localhost:8080' \
  --title='TechGear Pro' \
  --admin_user='admin' \
  --admin_password='TechGear2024!' \
  --admin_email='admin@techgearpro.local' \
  --skip-email \
  --allow-root
```

## Verify Everything Works

After successful installation:

```bash
# Check site is accessible
curl -I http://localhost:8080

# Check admin panel
curl -I http://localhost:8080/wp-admin

# List users
sudo docker compose exec wpcli wp user list --allow-root

# Check plugins
sudo docker compose exec wpcli wp plugin list --allow-root

# Check database
sudo docker compose exec db mysql -u wordpress -pwordpress_pass wordpress -e "SELECT COUNT(*) FROM wp_posts;"
```

## Next Steps

Once WordPress is installed and accessible:

1. Login to http://localhost:8080/wp-admin
2. Verify you can access the dashboard
3. Then run the setup script to install plugins and content:
   ```bash
   sudo docker compose exec wpcli bash /setup.sh
   ```

Or install components manually as shown in Step 9.

# Troubleshooting Guide

## HTTP_HOST Undefined Error

### Symptoms
```
PHP Warning: Undefined array key "HTTP_HOST" in /var/www/html/wp-includes/functions.php
```

This error appears when running WP-CLI commands because the CLI environment doesn't have HTTP headers.

### Solution 1: Quick Fix Script (Fastest)
```bash
sudo bash fix-http-host.sh
# Then run setup:
sudo docker compose exec wpcli bash /setup.sh
```

### Solution 2: Manual Fix
```bash
# Set WordPress URL in wp-config.php
sudo docker compose exec wpcli wp config set WP_HOME "http://localhost:8080" --allow-root
sudo docker compose exec wpcli wp config set WP_SITEURL "http://localhost:8080" --allow-root

# Create wp-cli.yml
sudo docker compose exec wpcli bash -c 'cat > /var/www/html/wp-cli.yml << EOF
url: http://localhost:8080
allow-root: true
EOF'

# Update database
sudo docker compose exec wpcli wp option update home "http://localhost:8080" --allow-root
sudo docker compose exec wpcli wp option update siteurl "http://localhost:8080" --allow-root
```

### Solution 3: Redeploy with Updated Files
If you're starting fresh:
```bash
sudo docker compose down -v
# Download the updated package
sudo docker compose up -d
# The new setup.sh handles this automatically
```

## Docker Layer Corruption

### Symptoms
```
failed to register layer: symlink ... no such file or directory
```

### Solution 1: Light Cleanup (Try this first)
```bash
sudo docker compose down
sudo docker system prune -f
sudo docker compose up -d
```

### Solution 2: Use the cleanup script
```bash
sudo bash docker-cleanup.sh
# Choose option 1 for light cleanup
# Then: sudo docker compose up -d
```

### Solution 3: Full Docker cleanup
```bash
sudo docker compose down
sudo docker system prune -a --volumes
sudo docker compose up -d
```

### Solution 4: Restart Docker daemon
```bash
sudo systemctl restart docker
sudo docker compose up -d
```

## Obsolete Version Warning

### Symptom
```
WARN[0000] the attribute `version` is obsolete
```

### Solution
This is just a warning and won't affect functionality. The updated `docker-compose.yml` has this fixed. If you're using an old version:

```bash
# Download the updated files or manually edit docker-compose.yml
# Remove the line: version: '3.8'
```

## Port Already in Use

### Symptoms
```
Bind for 0.0.0.0:8080 failed: port is already allocated
```

### Solution 1: Find what's using the port
```bash
sudo lsof -i :8080
# Kill the process or use a different port
```

### Solution 2: Change the port
Edit `docker-compose.yml`:
```yaml
nginx:
  ports:
    - "8090:80"  # Changed from 8080 to 8090
```

Then access site at http://localhost:8090

## WordPress Not Accessible

### Check 1: Are containers running?
```bash
sudo docker compose ps

# Should show all containers as "Up"
# If not, check logs
```

### Check 2: View container logs
```bash
sudo docker compose logs wordpress
sudo docker compose logs nginx
sudo docker compose logs db
```

### Check 3: Restart containers
```bash
sudo docker compose restart
```

### Check 4: Verify nginx is listening
```bash
sudo docker compose exec nginx netstat -tlnp
# Should show nginx listening on port 80
```

## Setup Script Fails

### Error: "WordPress not installed"
```bash
# WordPress needs time to initialize
# Wait 2-3 minutes, then try again
sudo docker compose logs -f wordpress
# Wait for "ready to handle connections"
# Press Ctrl+C
sudo docker compose exec wpcli bash /setup.sh
```

### Error: "Could not install plugin"
```bash
# Network issue or plugin repository down
# Check internet connectivity
ping wordpress.org

# Try manual plugin installation
sudo docker compose exec wpcli wp plugin install woocommerce --activate --allow-root
```

### Error: "Database connection failed"
```bash
# Database not ready yet
sudo docker compose logs db
# Wait for "ready for connections"

# Or restart db container
sudo docker compose restart db
sleep 30
sudo docker compose exec wpcli bash /setup.sh
```

## Products Not Importing

### Check 1: Verify CSV file exists
```bash
sudo docker compose exec wpcli ls -l /products.csv
```

### Check 2: Manually import
```bash
sudo docker compose exec wpcli wp wc product import /products.csv --user=admin --allow-root
```

### Check 3: Check for errors
```bash
sudo docker compose logs wordpress | grep -i error
```

### Check 4: Import one product at a time
```bash
# Create a test product
sudo docker compose exec wpcli wp wc product create \
  --name="Test Product" \
  --type=simple \
  --regular_price=99.99 \
  --user=admin --allow-root
```

## Permission Errors

### Error: "Permission denied"
```bash
# WP-CLI needs to run as user www-data (ID 33)
# This is already configured, but if you see errors:

sudo docker compose exec -u 33:33 wpcli wp --info --allow-root
```

### Fix file permissions
```bash
sudo docker compose exec wordpress chown -R www-data:www-data /var/www/html
```

## Memory Issues

### Error: "Allowed memory size exhausted"

Edit `docker-compose.yml`:
```yaml
wordpress:
  environment:
    WORDPRESS_CONFIG_EXTRA: |
      define('WP_MEMORY_LIMIT', '512M');
```

Then:
```bash
sudo docker compose down
sudo docker compose up -d
```

## Network Issues

### Can't pull images
```bash
# Check internet connectivity
ping docker.io

# Try with different DNS
echo '{"dns": ["8.8.8.8", "8.8.4.4"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

### Containers can't communicate
```bash
# Check network
sudo docker network ls
sudo docker network inspect wordpress-waf-training_techgear_network

# Recreate network
sudo docker compose down
sudo docker network prune
sudo docker compose up -d
```

## Performance Issues

### Site is slow
```bash
# Check resource usage
sudo docker stats

# Increase resources in docker-compose.yml
# Add under each service:
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

### Database is slow
```bash
# Check MySQL performance
sudo docker compose exec db mysqladmin status -u root -proot_pass

# Increase MySQL buffer pool
# Edit docker-compose.yml, add under db environment:
MYSQL_INNODB_BUFFER_POOL_SIZE: 512M
```

## Volume Issues

### Error: "Volume is in use"
```bash
# Stop all containers using the volume
sudo docker compose down

# List volumes
sudo docker volume ls

# Remove specific volume
sudo docker volume rm wordpress-waf-training_wordpress_data

# Or remove all unused volumes
sudo docker volume prune
```

### Reset to clean state
```bash
# WARNING: This deletes ALL data
sudo docker compose down -v
sudo docker compose up -d
# Wait for initialization
sudo docker compose exec wpcli bash /setup.sh
```

## SSL/TLS Issues (if adding HTTPS later)

### Mixed content warnings
```bash
# Update site URL in database
sudo docker compose exec wpcli wp option update home 'https://your-domain.com' --allow-root
sudo docker compose exec wpcli wp option update siteurl 'https://your-domain.com' --allow-root

# Search and replace
sudo docker compose exec wpcli wp search-replace 'http://localhost:8080' 'https://your-domain.com' --allow-root
```

## WP-CLI Issues

### Error: "wp: command not found"
```bash
# WP-CLI is in a separate container
# Always use:
sudo docker compose exec wpcli wp <command> --allow-root

# NOT:
sudo docker compose exec wordpress wp <command>
```

### WP-CLI hangs
```bash
# Check if WordPress is ready
sudo docker compose exec wordpress curl -I http://localhost

# Restart WP-CLI container
sudo docker compose restart wpcli
```

## Logs and Debugging

### Enable WordPress debug mode
Already enabled by default. View logs:
```bash
sudo docker compose exec wordpress tail -f /var/www/html/wp-content/debug.log
```

### View all logs
```bash
# Real-time logs from all containers
sudo docker compose logs -f

# Last 100 lines from specific container
sudo docker compose logs --tail=100 wordpress

# Search logs for errors
sudo docker compose logs | grep -i error
```

### nginx access logs
```bash
sudo docker compose exec nginx tail -f /var/log/nginx/access.log
```

### MySQL query log
```bash
# Enable query log temporarily
sudo docker compose exec db mysql -u root -proot_pass -e "SET GLOBAL general_log = 'ON';"

# View query log
sudo docker compose exec db tail -f /var/lib/mysql/mysql-general.log
```

## Complete Reset

If nothing else works:

```bash
# Stop everything
sudo docker compose down -v

# Clean Docker
sudo bash docker-cleanup.sh
# Choose option 2 (full cleanup)

# Remove project directory
cd ..
rm -rf wordpress-waf-training

# Re-download and start fresh
# Extract the archive again
cd wordpress-waf-training
sudo docker compose up -d
```

## Getting Help

### Diagnostic information
```bash
# Collect diagnostic info
echo "=== Docker Version ===" > diagnostic.txt
docker --version >> diagnostic.txt
echo "" >> diagnostic.txt

echo "=== Docker Compose Version ===" >> diagnostic.txt
docker compose version >> diagnostic.txt
echo "" >> diagnostic.txt

echo "=== System Info ===" >> diagnostic.txt
uname -a >> diagnostic.txt
echo "" >> diagnostic.txt

echo "=== Container Status ===" >> diagnostic.txt
sudo docker compose ps >> diagnostic.txt
echo "" >> diagnostic.txt

echo "=== Container Logs ===" >> diagnostic.txt
sudo docker compose logs --tail=50 >> diagnostic.txt

cat diagnostic.txt
```

### Check system requirements
```bash
# Memory
free -h

# Disk space
df -h

# Docker info
sudo docker info
```

## Prevention

### Regular maintenance
```bash
# Weekly cleanup
sudo docker system prune -f

# Monthly cleanup
sudo docker system prune -a

# Check for updates
sudo docker compose pull
sudo docker compose up -d
```

### Monitor resources
```bash
# Real-time monitoring
sudo docker stats

# Disk usage
sudo docker system df
```

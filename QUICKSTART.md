# Quick Start Guide - TechGear Pro WAF Training

## Get Running in 5 Minutes

### Step 1: Start the Environment
```bash
cd wordpress-waf-training
docker-compose up -d
```

### Step 2: Wait for WordPress (60 seconds)
```bash
# Watch the logs until you see "ready to handle connections"
docker-compose logs -f wordpress
# Press Ctrl+C when ready
```

### Step 3: Run Setup Script
```bash
docker-compose exec wpcli bash /setup.sh
```
⏱️ This takes 5-10 minutes. Grab a coffee!

### Step 4: Access the Site
- **WordPress**: http://localhost:8080
- **Admin Panel**: http://localhost:8080/wp-admin
  - Username: `admin`
  - Password: `TechGear2024!`
- **phpMyAdmin**: http://localhost:8081

## First Training Exercise (15 minutes)

### Test False Positives

1. **Search for products with special characters:**
   - Go to http://localhost:8080
   - Search for: `O'Reilly's`
   - Search for: `15" MacBook`
   - Search for: `SELECT * FROM users`

2. **Submit a technical support form:**
   - Find "Contact" or create a support form
   - Enter error message: `Error: Cannot connect to database at 192.168.1.1`
   - Include a "code snippet": `<configuration><debug>true</debug></configuration>`

3. **Add a product review:**
   - Go to any product
   - Write review: "Fixed my issue! Was seeing 'SELECT failed' error in /var/log/app.log"

4. **Check your WAF logs** for false positives in:
   - SQL injection rules
   - XSS rules  
   - Path traversal rules
   - Rate limiting

## Useful Commands

### View Logs
```bash
# All logs
docker-compose logs -f

# Just WordPress
docker-compose logs -f wordpress

# Just nginx
docker-compose logs -f nginx
```

### WP-CLI Commands
```bash
# List all products
docker-compose exec wpcli wp wc product list --allow-root

# List all users
docker-compose exec wpcli wp user list --allow-root

# List orders
docker-compose exec wpcli wp wc shop_order list --allow-root

# Create a new admin user
docker-compose exec wpcli wp user create testadmin test@example.com \
  --role=administrator --user_pass=Test123! --allow-root
```

### Reset Everything
```bash
# Stop and remove all data (start fresh)
docker-compose down -v

# Start again
docker-compose up -d
docker-compose exec wpcli bash /setup.sh
```

## Test Accounts

**Admin:**
- admin / TechGear2024!

**Shop Manager:**
- shopmanager@techgearpro.local / Shop123!

**Customer:**
- alice@example.com / Customer123!
- bob@example.com / Customer123!

## Common Issues

**HTTP_HOST undefined error during setup?**
```bash
# Run the quick fix script first
sudo bash fix-http-host.sh
# Then run setup
sudo docker compose exec wpcli bash /setup.sh
```

**Docker layer corruption error?**
```bash
# Run the cleanup script
sudo bash docker-cleanup.sh
# Choose option 1 (light cleanup) first
# Then try: sudo docker compose up -d
```

**Can't access site on :8080?**
- Check if port is available: `lsof -i :8080`
- Change port in docker-compose.yml if needed

**Setup script fails?**
- Wait longer for WordPress to initialize
- Check logs: `docker-compose logs wordpress`
- Try again: `docker-compose exec wpcli bash /setup.sh`

**Products didn't import?**
- Manually import: `docker-compose exec wpcli wp wc product import /products.csv --user=admin --allow-root`

**"version is obsolete" warning?**
- This is just a warning, it won't affect functionality
- The warning has been fixed in the latest docker-compose.yml

## Next Steps

1. ✅ Place site behind your WAF
2. ✅ Test all scenarios from README.md
3. ✅ Document false positives
4. ✅ Tune WAF rules
5. ✅ Train your team!

---

**Full documentation**: See README.md

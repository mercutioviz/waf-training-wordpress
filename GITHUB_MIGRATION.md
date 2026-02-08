# GitHub Repository Migration Guide

## Current Situation
- Existing repo: https://github.com/mercutioviz/waf-training-wordpress
- Old code focuses on: "Summit Outfitters" with header/parameter limits
- New code: TechGear Pro with SQL injection/XSS false positives
- Location: /home/azureuser/waf-training-wordpress

## Migration Steps

### Step 1: Backup Current Work (Optional)
```bash
cd /home/azureuser/waf-training-wordpress
git branch old-version-backup
git push origin old-version-backup
```

### Step 2: Clean Local Directory
```bash
cd /home/azureuser/waf-training-wordpress

# Remove all files except .git directory
find . -maxdepth 1 ! -name '.git' ! -name '.' -exec rm -rf {} +

# Verify only .git remains
ls -la
# Should only show . .. .git
```

### Step 3: Download New Code

**Option A: Direct download (if you upload the file somewhere)**
```bash
# You'll need to upload wordpress-waf-training.tar.gz to a server
# Then:
wget https://your-server.com/wordpress-waf-training.tar.gz
tar -xzf wordpress-waf-training.tar.gz
mv wordpress-waf-training/* .
mv wordpress-waf-training/.* . 2>/dev/null || true
rm -rf wordpress-waf-training wordpress-waf-training.tar.gz
```

**Option B: Using Claude's file (recommended)**
Since you have the downloaded file from Claude, you can:
```bash
# If you downloaded to your Windows machine, upload to Linux:
# (From your Windows machine)
scp wordpress-waf-training.tar.gz azureuser@your-linux-ip:/home/azureuser/

# Then on Linux:
cd /home/azureuser/waf-training-wordpress
tar -xzf ../wordpress-waf-training.tar.gz
mv wordpress-waf-training/* .
mv wordpress-waf-training/.env.example . 2>/dev/null || true
rm -rf wordpress-waf-training
```

**Option C: Manual file creation (if download is difficult)**
See MANUAL_CREATION.md for step-by-step file creation

### Step 4: Update Repository-Specific Files

Create/update .gitignore:
```bash
cat > .gitignore << 'EOF'
# Docker volumes and data
mysql_data/
wordpress_data/
logs/

# Environment variables
.env

# OS files
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Backup files
*.bak
*~

# Temporary files
*.tmp
*.log
EOF
```

Keep the existing LICENSE file:
```bash
# The repo already has an MIT LICENSE, keep it
git checkout LICENSE
```

### Step 5: Review Changes
```bash
git status
git diff README.md  # Compare old vs new
```

### Step 6: Commit and Push
```bash
# Stage all changes
git add .

# Commit with descriptive message
git commit -m "Complete rewrite: TechGear Pro WAF training environment

- Focus shifted from parameter limits to SQL/XSS false positives
- New automated setup with 50 products, multiple forms
- Comprehensive documentation and troubleshooting guides
- Better WordPress initialization handling
- Added diagnostic tools and manual installation guides"

# Push to GitHub
git push origin main
```

### Step 7: Update GitHub Repository Settings

On GitHub (https://github.com/mercutioviz/waf-training-wordpress):

1. Go to **Settings** > **General**
2. Update **Description**: 
   ```
   WordPress WAF training environment - TechGear Pro e-commerce site with built-in false positive scenarios for SQL injection, XSS, and path traversal detection
   ```
3. Add **Topics**: `waf`, `wordpress`, `security-training`, `false-positives`, `woocommerce`, `docker`
4. Optionally add a **Website**: Link to live demo if you deploy one

### Step 8: Create GitHub Release (Optional)

```bash
git tag -a v1.0.0 -m "Initial release of TechGear Pro WAF training environment"
git push origin v1.0.0
```

Then on GitHub, go to **Releases** > **Draft a new release** and create release notes.

## File Structure Comparison

**Old Structure:**
```
waf-training-wordpress/
├── config/
├── data/
├── scripts/
├── tools/
├── wordpress/
├── docker-compose.yml
└── README.md
```

**New Structure:**
```
waf-training-wordpress/
├── docker-compose.yml
├── nginx.conf
├── setup.sh
├── test-waf.sh
├── docker-cleanup.sh
├── fix-http-host.sh
├── diagnose-wordpress.sh
├── products.csv
├── forms-config.json
├── wp-cli.yml
├── .env.example
├── README.md
├── QUICKSTART.md
├── TROUBLESHOOTING.md
├── MANUAL_INSTALL.md
├── FALSE_POSITIVES.md
├── DEPLOYMENT_SUMMARY.md
├── example-modsecurity.conf
└── LICENSE
```

## Key Differences

### Old Version (Summit Outfitters)
- Focus: Header/parameter length limits
- Setup: Multi-directory structure with separate scripts
- Products: ~250 outdoor gear items
- Training: Parameter and header limit tuning

### New Version (TechGear Pro)
- Focus: SQL injection, XSS, path traversal false positives
- Setup: Single-directory with integrated scripts
- Products: 50 tech items with special characters
- Training: Rule tuning and exception creation
- Includes: Comprehensive diagnostics and troubleshooting

## Post-Migration Testing

After pushing to GitHub:

```bash
# Clone in a fresh location to test
cd /tmp
git clone https://github.com/mercutioviz/waf-training-wordpress.git test-clone
cd test-clone

# Verify all files are present
ls -la

# Test deployment
sudo docker compose up -d
# Wait 60 seconds
sudo docker compose exec wpcli bash /setup.sh
```

## Troubleshooting

### If git push is rejected (due to history)

```bash
# Force push (only if you're sure!)
git push origin main --force
```

⚠️ **Warning**: Force push will overwrite GitHub history. Make sure you have a backup!

### If you want to preserve old version

```bash
# Create a branch for old version before cleaning
git checkout -b old-summit-outfitters
git push origin old-summit-outfitters
git checkout main
# Then proceed with cleaning
```

## Verification Checklist

After migration:

- [ ] All new files present in GitHub
- [ ] README.md displays correctly
- [ ] QUICKSTART.md is accessible
- [ ] docker-compose.yml has no version field
- [ ] .gitignore excludes data/logs
- [ ] LICENSE file preserved
- [ ] Repository description updated
- [ ] Topics/tags added
- [ ] Fresh clone works correctly
- [ ] Docker compose up succeeds
- [ ] Setup script runs

## Need Help?

If you encounter issues:
1. Check git status
2. Review error messages
3. Verify file permissions
4. Ensure .git directory wasn't deleted
5. Check GitHub authentication

---

**Ready to migrate?** Follow the steps above!

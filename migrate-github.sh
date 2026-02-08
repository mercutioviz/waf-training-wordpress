#!/bin/bash
# GitHub Migration - Exact Commands
# Run this script from your waf-training-wordpress directory

set -e

echo "=========================================="
echo "GitHub Migration Script"
echo "=========================================="
echo ""
echo "This will replace all files in your repo with the new TechGear Pro version"
echo ""
read -p "Are you in /home/azureuser/waf-training-wordpress? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Please cd to the correct directory first"
    exit 1
fi

# Verify we're in a git repo
if [ ! -d .git ]; then
    echo "ERROR: Not a git repository"
    exit 1
fi

echo ""
echo "Step 1: Creating backup branch..."
git branch old-version-backup 2>/dev/null || echo "Backup branch already exists"
git push origin old-version-backup 2>/dev/null || echo "Backup already pushed"

echo ""
echo "Step 2: Cleaning local directory (keeping .git)..."
find . -maxdepth 1 ! -name '.git' ! -name '.' ! -name '..' -exec rm -rf {} +

echo ""
echo "Step 3: Waiting for file upload..."
echo ""
echo "PAUSE: Please download wordpress-waf-training.tar.gz from Claude"
echo "       and upload it to /home/azureuser/ on your Linux machine"
echo ""
echo "You can use scp from your Windows machine:"
echo "  scp wordpress-waf-training.tar.gz azureuser@YOUR_IP:/home/azureuser/"
echo ""
read -p "Press Enter once file is uploaded to /home/azureuser/..."

if [ ! -f /home/azureuser/wordpress-waf-training.tar.gz ]; then
    echo "ERROR: File not found at /home/azureuser/wordpress-waf-training.tar.gz"
    exit 1
fi

echo ""
echo "Step 4: Extracting files..."
tar -xzf /home/azureuser/wordpress-waf-training.tar.gz -C /tmp/
mv /tmp/wordpress-waf-training/* .
mv /tmp/wordpress-waf-training/.env.example . 2>/dev/null || true
rm -rf /tmp/wordpress-waf-training

echo ""
echo "Step 5: Creating .gitignore..."
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

echo ""
echo "Step 6: Making scripts executable..."
chmod +x *.sh 2>/dev/null || true

echo ""
echo "Step 7: Reviewing changes..."
git status

echo ""
echo "Files ready for commit!"
echo ""
echo "Next steps:"
echo "  1. Review the changes above"
echo "  2. Run: git add ."
echo "  3. Run: git commit -m 'Complete rewrite: TechGear Pro WAF training environment'"
echo "  4. Run: git push origin main"
echo ""

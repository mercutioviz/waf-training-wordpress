#!/bin/bash
# Backup script for WAF training environment

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="waf-training-backup-${TIMESTAMP}"

echo "WAF Training Environment Backup"
echo "================================"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_NAME"
echo ""

# Backup database
echo "Backing up database..."
docker exec waf-training-db mysqldump -u wordpress -pwordpress_password_change_me wordpress > "$BACKUP_DIR/${BACKUP_NAME}-database.sql"

if [ $? -eq 0 ]; then
    echo "✓ Database backup complete"
    gzip "$BACKUP_DIR/${BACKUP_NAME}-database.sql"
    echo "✓ Database backup compressed"
else
    echo "✗ Database backup failed"
    exit 1
fi

# Backup WordPress files
echo ""
echo "Backing up WordPress files..."
docker exec waf-training-wordpress tar -czf /tmp/wordpress-backup.tar.gz -C /var/www/html .
docker cp waf-training-wordpress:/tmp/wordpress-backup.tar.gz "$BACKUP_DIR/${BACKUP_NAME}-wordpress.tar.gz"
docker exec waf-training-wordpress rm /tmp/wordpress-backup.tar.gz

if [ $? -eq 0 ]; then
    echo "✓ WordPress files backup complete"
else
    echo "✗ WordPress files backup failed"
    exit 1
fi

# Backup .env file
echo ""
echo "Backing up configuration..."
if [ -f .env ]; then
    cp .env "$BACKUP_DIR/${BACKUP_NAME}-env.txt"
    echo "✓ Configuration backup complete"
fi

# Create backup manifest
echo ""
echo "Creating backup manifest..."
cat > "$BACKUP_DIR/${BACKUP_NAME}-manifest.txt" << EOF
WAF Training Environment Backup
Created: $(date)
Hostname: $(hostname)

Contents:
- ${BACKUP_NAME}-database.sql.gz (Database dump)
- ${BACKUP_NAME}-wordpress.tar.gz (WordPress files)
- ${BACKUP_NAME}-env.txt (Environment configuration)

To restore:
1. Stop containers: docker-compose down
2. Restore database: gunzip < ${BACKUP_NAME}-database.sql.gz | docker exec -i waf-training-db mysql -u wordpress -p wordpress
3. Restore files: docker cp ${BACKUP_NAME}-wordpress.tar.gz waf-training-wordpress:/tmp/ && docker exec waf-training-wordpress tar -xzf /tmp/${BACKUP_NAME}-wordpress.tar.gz -C /var/www/html
4. Restore .env: cp ${BACKUP_NAME}-env.txt .env
5. Restart: docker-compose up -d
EOF

echo "✓ Backup manifest created"

# Calculate sizes
echo ""
echo "Backup Summary"
echo "--------------"
du -h "$BACKUP_DIR/${BACKUP_NAME}"* | awk '{print $1 "\t" $2}'

echo ""
echo "Backup complete!"
echo "Location: $BACKUP_DIR/"
echo ""
echo "To restore this backup, see: $BACKUP_DIR/${BACKUP_NAME}-manifest.txt"

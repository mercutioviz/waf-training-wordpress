#!/bin/bash
# Health check script for WordPress container

set -e

# Check if Apache is responding
curl -f http://localhost/wp-admin/install.php >/dev/null 2>&1 || exit 1

# Check if WordPress files exist
test -f /var/www/html/wp-config.php || exit 1

# Check if we can connect to database
php -r "
\$mysqli = new mysqli('${WORDPRESS_DB_HOST}', '${WORDPRESS_DB_USER}', '${WORDPRESS_DB_PASSWORD}', '${WORDPRESS_DB_NAME}');
if (\$mysqli->connect_error) {
    exit(1);
}
\$mysqli->close();
" || exit 1

exit 0

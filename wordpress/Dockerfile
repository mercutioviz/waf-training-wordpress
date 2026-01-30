ARG WORDPRESS_VERSION=latest
FROM wordpress:${WORDPRESS_VERSION}

# Install additional packages
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    less \
    vim \
    git \
    unzip \
    mariadb-client \
    imagemagick \
    libmagickwand-dev \
    ghostscript \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Configure WP-CLI to run as www-data
RUN mkdir -p /var/www/.wp-cli/cache \
    && chown -R www-data:www-data /var/www/.wp-cli

# Install additional PHP extensions
RUN docker-php-ext-install exif

# Enable Apache modules
RUN a2enmod rewrite expires headers

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

# Health check script
COPY --chown=www-data:www-data healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

WORKDIR /var/www/html

# Use default WordPress entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]

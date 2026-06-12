FROM php:8.2-apache

# Install system dependencies and tools (including docker.io for Docker CLI and rclone)
RUN apt-get update && apt-get install -y \
    docker.io \
    rclone \
    zstd \
    bash \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Note: Docker CLI access is via the mounted /var/run/docker.sock from the host.
# We install the Docker CLI client (docker.io) inside the container so it can communicate with the socket.


# Configure Apache
RUN a2enmod rewrite
RUN echo '<Directory /var/www/html>\n    AllowOverride All\n</Directory>' > /etc/apache2/conf-available/docker-php.conf
RUN a2enconf docker-php

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY public/ /var/www/html/
COPY includes/ /var/www/html/includes/

# Set permissions
RUN chown -R www-data:www-data /var/www/html
RUN chmod -R 755 /var/www/html

# Add www-data to docker group (for Docker socket access)
RUN groupadd docker || true
RUN usermod -aG docker www-data

# Expose port 80
EXPOSE 80


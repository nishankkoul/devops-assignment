# Use the Yii2 PHP 8.2 base image
FROM yiisoftware/yii2-php:8.2-fpm

# Set working directory inside the container
WORKDIR /app

# Copy the current directory (application code) to the container
COPY . /app

# Set up Composer (PHP dependency manager) and install dependencies
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer install --no-dev --optimize-autoloader

# Expose port 8080 (the application will run on this port)
EXPOSE 8080

# Start PHP's built-in server to run Yii2 on port 8080
CMD php -S 0.0.0.0:8080 -t web


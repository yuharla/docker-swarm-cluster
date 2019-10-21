FROM php:7.3.10-apache-buster

ENV COMPOSER_ALLOW_SUPERUSER=1

EXPOSE 80
WORKDIR /data

RUN apt-get update -qy && \
    apt-get install -y \
    git \
    libicu-dev \
    unzip \
    zip \
    php-redis \
    vim \
    && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# PHP Extensions
RUN docker-php-ext-install -j$(nproc) opcache pdo_mysql pdo_odbc
ADD conf/php.ini /usr/local/etc/php/conf.d/app.ini
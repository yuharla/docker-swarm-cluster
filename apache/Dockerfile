FROM php:7.3.10-apache-buster

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV ACCEPT_EULA=Y

EXPOSE 80

RUN rm -f /etc/apt/preferences.d/no-debian-php && \
    apt-get update -qy && \
    apt upgrade -y && \
    apt -y autoremove && \
    apt-get install -y -q \
    apt-utils \
    locales \
    gnupg2 \
    cronolog \
    apt-transport-https \
    libxml2-dev \
    curl \
    git \
    libicu-dev \
    unzip \
    zip \
    php-redis \
    php7.3-dev \
    php7.3-xml \
    php7.3-curl \
    php7.3-intl \
    php-imagick \
    php-apcu \
    vim \
    && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get -qy install msodbcsql17 mssql-tools && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /root/.bash_profile && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /root/.bashrc && \
    apt-get install -y unixodbc unixodbc-dev && \   
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# PHP Extensions
RUN docker-php-ext-install -j$(nproc) opcache pdo_mysql mbstring soap && \
    pecl install sqlsrv pdo_sqlsrv xdebug && \
    docker-php-ext-enable sqlsrv pdo_sqlsrv xdebug

# PHP Configuration 
RUN sed -i "s/short_open_tag = On/short_open_tag = Off/" /usr/local/etc/php/php.ini-production && \
    sed -i "s/error_reporting = E_ALL & ~E_DEPRECATED/error_reporting = E_ALL/" /usr/local/etc/php/php.ini-production && \
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 12M/" /usr/local/etc/php/php.ini-production && \
    sed -i "s/expose_php = On/expose_php = Off/" /usr/local/etc/php/php.ini-production && \
    sed -i "s#;date.timezone =#date.timezone = Europe/Paris#" /usr/local/etc/php/php.ini-production

# APACHE CONFIGURATION
RUN cd /etc/apache2/mods-available && \
    a2enmod rewrite && \
    a2enmod headers && \
    a2enmod deflate && \
    a2enmod expires && \
    a2enmod http2 && \
    sed -i "s/ServerTokens OS/ServerTokens Prod/" /etc/apache2/conf-available/security.conf && \
    sed -i "s/ServerSignature On/ServerSignature Off/" /etc/apache2/conf-available/security.conf && \
    echo "Options -Indexes" >> /etc/apache2/conf-available/security.conf

# Folder Configuration
RUN rm -Rf /var/www/html &&\
    cd /var/www && \
    mkdir {webroot,log,tmp} && \
    chown -R www-data:www-data webroot && \
    chown -R www-data:www-data tmp && chmod 777
    

ADD conf/000-default.conf /etc/apache2/site-available/000-default.conf

RUN service apache2 restart






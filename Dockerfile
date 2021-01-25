FROM php:7.4

RUN apt-get update \
    && apt-get install -y \
        gnupg \
        libcurl4-openssl-dev \
        sudo \
        git \
        libxslt-dev \
        libonig-dev \
        zlib1g-dev \
        graphviz \
        libzip-dev \
        zip \
        libmcrypt-dev \
        libicu-dev \
        g++ \
        libpcre3-dev \
        libgd-dev \
        libfreetype6-dev \
        sqlite \
        curl \
        build-essential \
        unzip \
        gcc \
        make \
        autoconf \
        libc-dev \
        pkg-config \
        pv \
    && apt-get clean
RUN docker-php-ext-install \
        soap \
        zip \
        xsl \
        mbstring \
        gettext \
        curl \
        pdo_mysql \
        mysqli \
        json \
        intl \
        opcache \
    && docker-php-ext-enable mysqli \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install gd \
    && pecl install --nodeps mcrypt-snapshot \
    && docker-php-ext-enable mcrypt \
    && mkdir -p /tmp-libsodium/libsodium \
    && cd /tmp-libsodium/libsodium \
    && curl -L https://download.libsodium.org/libsodium/releases/libsodium-1.0.18.tar.gz -o libsodium-1.0.18.tar.gz \
    && tar xfvz libsodium-1.0.18.tar.gz \
    && cd /tmp-libsodium/libsodium/libsodium-1.0.18/ \
    && ./configure \
    && make \
    && make check \
    && make install \
    && mv src/libsodium /usr/local/ \
    && rm -Rf /tmp-libsodium/ \
    && docker-php-ext-install sodium \
    && docker-php-ext-enable sodium \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install mariadb-server \
    && service mysql start \
    && mysql -uroot -e "create database migrate;"

RUN echo "memory_limit = -1;" > $PHP_INI_DIR/conf.d/memory_limit.ini

# Set MySQL settings to speed up import
RUN echo "net_buffer_length=1000000" >> /etc/mysql/my.cnf
RUN echo "max_allowed_packet=1000000000" >> /etc/mysql/my.cnf

# Restart mysql to make settings work
RUN service mysql stop && service mysql start

# Install Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN curl -sS https://getcomposer.org/installer | php -- --1 --install-dir=/usr/local/bin --filename=composer \
    && composer global require "fxp/composer-asset-plugin:^1.4.2"

# Install Node
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash \
    && apt-get install -y nodejs \
    && apt-get clean

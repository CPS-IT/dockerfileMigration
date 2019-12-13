FROM php:7.2-stretch

RUN apt-get update \
    && apt-get install -y gnupg libcurl4-openssl-dev sudo git libxslt-dev zlib1g-dev graphviz zip libmcrypt-dev libicu-dev g++ libpcre3-dev libgd-dev libfreetype6-dev sqlite curl build-essential unzip gcc make autoconf libc-dev pkg-config pv \
    && apt-get clean \
    && docker-php-ext-install soap \
    && docker-php-ext-install zip \
    && docker-php-ext-install xsl \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install gettext \
    && docker-php-ext-install curl \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install mysqli \
    && docker-php-ext-enable mysqli \
    && docker-php-ext-install json \
    && docker-php-ext-install intl \
    && docker-php-ext-install opcache \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && pecl install --nodeps mcrypt-snapshot \
    && docker-php-ext-enable mcrypt \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-server && service mysql start && mysql -uroot -e "create database migrate;"

RUN echo "memory_limit = -1;" > $PHP_INI_DIR/conf.d/memory_limit.ini

# Set MySQL settings to speed up import
RUN echo "net_buffer_length=1000000" >> /etc/mysql/my.cnf
RUN echo "max_allowed_packet=1000000000" >> /etc/mysql/my.cnf

# Restart mysql to make settings work
RUN service mysql stop && service mysql start


ENV COMPOSER_ALLOW_SUPERUSER=1

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && composer global require "fxp/composer-asset-plugin:^1.4.2"



RUN curl -sL https://deb.nodesource.com/setup_6.x | bash && apt-get install -y nodejs && apt-get clean

#Install blackfire client
RUN mkdir -p /tmp/blackfire \
    && curl -A "Docker" -L https://blackfire.io/api/v1/releases/client/linux_static/amd64 | tar zxp -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire /usr/bin/blackfire \
    && rm -Rf /tmp/blackfire

#Install blackfire php module
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && mkdir -p /tmp/blackfire \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz
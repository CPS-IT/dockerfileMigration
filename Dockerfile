FROM php:7.2

# VERSIONS
ENV ALPINE_VERSION=3.8 \
    PYTHON_VERSION=2.7.15

ENV PYTHON_PATH=/usr/local/bin/ \
    PATH="/usr/local/lib/python$PYTHON_VERSION/bin/:/usr/local/lib/pyenv/versions/$PYTHON_VERSION/bin:${PATH}" \
    # These are always installed. Notes:
    #   * dumb-init: a proper init system for containers, to reap zombie children
    #   * bash: For entrypoint, and debugging
    #   * ca-certificates: for SSL verification during Pip and easy_install
    PACKAGES="\
      dumb-init \
      bash \
      ca-certificates \
    " \
    # PACKAGES needed to built python
    PYTHON_BUILD_PACKAGES="\
      bzip2-dev \
      coreutils \
      dpkg-dev dpkg \
      expat-dev \
      findutils \
      gcc \
      gdbm-dev \
      libc-dev \
      libffi-dev \
      libnsl-dev \
      libtirpc-dev \
      linux-headers \
      make \
      ncurses-dev \
      libressl-dev \
      pax-utils \
      readline-dev \
      sqlite-dev \
      tcl-dev \
      tk \
      tk-dev \
      util-linux-dev \
      xz-dev \
      zlib-dev \
      git \
    " \
    # These packages are not installed immediately, but are added at runtime or ONBUILD to shrink the image as much as possible. Notes:
    #   * build-base: used so we include the basic development packages (gcc)
    #   * linux-headers: commonly needed, and an unusual package name from Alpine.
    #   * lib6-compat: compatibility libraries for glibc
    #   * git: to ease up clones of repos
    BUILD_PACKAGES="\
      build-base \
      linux-headers \
      libc6-compat \
      git \
    "

RUN set -ex ;\
    # find MAJOR and MINOR python versions based on $PYTHON_VERSION
    export PYTHON_MAJOR_VERSION=$(echo "${PYTHON_VERSION}" | rev | cut -d"." -f3-  | rev) ;\
    export PYTHON_MINOR_VERSION=$(echo "${PYTHON_VERSION}" | rev | cut -d"." -f2-  | rev) ;\
    # replacing default repositories with edge ones
    echo "http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/community" >> /etc/apk/repositories ;\
    echo "http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/main" >> /etc/apk/repositories ;\
    # Add the packages, with a CDN-breakage fallback if needed
    apk add --no-cache $PACKAGES || \
        (sed -i -e 's/dl-cdn/dl-4/g' /etc/apk/repositories && apk add --no-cache $PACKAGES) ;\
    # Add packages just for the python build process with a CDN-breakage fallback if needed
    apk add --no-cache --virtual .build-deps $PYTHON_BUILD_PACKAGES || \
        (sed -i -e 's/dl-cdn/dl-4/g' /etc/apk/repositories && apk add --no-cache --virtual .build-deps $PYTHON_BUILD_PACKAGES) ;\
    # turn back the clock -- so hacky!
    echo "http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/main/" > /etc/apk/repositories ;\
    # echo "@community http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/community" >> /etc/apk/repositories ;\
    # echo "@testing http://dl-cdn.alpinelinux.org/alpine/v$ALPINE_VERSION/testing" >> /etc/apk/repositories ;\
    # echo "@edge-main http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories ;\
    # use pyenv to download and compile specific python version
    git clone --depth 1 https://github.com/pyenv/pyenv /usr/local/lib/pyenv ;\
    # install
    GNU_ARCH="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" ;\
    PYENV_ROOT=/usr/local/lib/pyenv CONFIGURE_OPTS="--build=$GNU_ARCH --enable-loadable-sqlite-extensions --enable-shared --with-system-expat --with-system-ffi --without-ensurepip --with-shared" /usr/local/lib/pyenv/bin/pyenv install $PYTHON_VERSION ;\
    # keep the needed .so files
    # ignore libpython - that one comes from the pyenv instalation
    find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
        | tr ',' '\n' \
        | sort -u \
        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
        | grep -ve 'libpython' \
        | xargs -rt apk add --no-cache --virtual .python-rundeps ;\
        # for debug
        # | xargs -n1 echo ;\
    # delete everything from pyenv except the installed version
    # this throws an error but we ignore it
    find /usr/local/lib/pyenv/ -mindepth 1 -name versions -prune -o -exec rm -rf {} \; || true ;\
    # delete files to to reduce container size
    # tips taken from main python docker repo
    find /usr/local/lib/pyenv/versions/$PYTHON_VERSION/ -depth \( -name '*.pyo' -o -name '*.pyc' -o -name 'test' -o -name 'tests' \) -exec rm -rf '{}' + ;\
    # symlink the binaries
    ln -s /usr/local/lib/pyenv/versions/$PYTHON_VERSION/bin/* $PYTHON_PATH ;\
    # remove build dependencies and any leftover apk cache
    apk del --no-cache --purge .build-deps ;\
    rm -rf /var/cache/apk/*

# Copy in the entrypoint script -- this installs prerequisites on container start.
COPY entrypoint.sh /entrypoint.sh

# This script installs APK and Pip prerequisites on container start, or ONBUILD. Notes:
#   * Reads the -a flags and /apk-requirements.txt for install requests
#   * Reads the -b flags and /build-requirements.txt for build packages -- removed when build is complete
#   * Reads the -p flags and /requirements.txt for Pip packages
#   * Reads the -r flag to specify a different file path for /requirements.txt
ENTRYPOINT ["/usr/bin/dumb-init", "bash", "/entrypoint.sh"]

RUN apt-get update \
    && apt-get install -y gnupg libcurl4-openssl-dev sudo git libxslt-dev zlib1g-dev graphviz zip libmcrypt-dev libicu-dev g++ libpcre3-dev libgd-dev libfreetype6-dev sqlite curl build-essential unzip gcc make autoconf libc-dev pkg-config \
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
    && mkdir -p /tmp-libsodium/libsodium \
    && cd /tmp-libsodium/libsodium \
    && curl -L https://download.libsodium.org/libsodium/releases/libsodium-1.0.16.tar.gz -o libsodium-1.0.16.tar.gz \
    && tar xfvz libsodium-1.0.16.tar.gz \
    && cd /tmp-libsodium/libsodium/libsodium-1.0.16/ \
    && ./configure \
    && make \
    && make check \
    && make install \
    && mv src/libsodium /usr/local/ \
    && rm -Rf /tmp-libsodium/ \
    && docker-php-ext-install sodium \
    && docker-php-ext-enable sodium \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-server && service mysql start && mysql -uroot -e "create database migrate;"

RUN echo "memory_limit = -1;" > $PHP_INI_DIR/conf.d/memory_limit.ini

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && composer global require "fxp/composer-asset-plugin:^1.4.2"



RUN curl -sL https://deb.nodesource.com/setup_6.x | bash && apt-get install -y nodejs && apt-get clean

# ──────────────────────────────────────────────────────────────
# PHP 8.3 — Laravel API pure (pas de Node/npm)
# ──────────────────────────────────────────────────────────────
FROM php:8.3-fpm-alpine

# Extensions requises pour PostgreSQL, Redis, GD
RUN apk add --no-cache \
        postgresql-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        freetype-dev \
        icu-dev \
        zip \
        unzip \
        git \
        curl \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql \
        pgsql \
        gd \
        intl \
        pcntl \
        bcmath \
        opcache

# Redis extension
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# PHP config
COPY docker/php.ini /usr/local/etc/php/conf.d/99-sortie.ini

WORKDIR /var/www

COPY . .

RUN composer install --optimize-autoloader --no-interaction 2>/dev/null || true

EXPOSE 9000

CMD ["php-fpm"]

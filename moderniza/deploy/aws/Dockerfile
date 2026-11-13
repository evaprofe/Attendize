# =============================================================================
# Imagen de PRODUCCIÓN de Moderniza (Tarea 5)
# Construcción (desde la carpeta moderniza/):
#   docker build -f deploy/aws/Dockerfile -t moderniza:tarea-05-rc1 .
# =============================================================================

# --- Etapa 1: compilar React + TypeScript con Vite ---------------------------
FROM node:22 AS assets
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY vite.config.js tsconfig.json ./
COPY resources ./resources
RUN npm run build

# --- Etapa 2: PHP 8.3 + Apache, solo dependencias de producción --------------
FROM php:8.3-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libzip-dev libicu-dev \
    && docker-php-ext-install pdo_mysql zip intl bcmath opcache \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

# Apache sirve la carpeta public/ de Laravel
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && echo "ServerTokens Prod\nServerSignature Off" > /etc/apache2/conf-available/zz-seguridad.conf \
    && a2enconf zz-seguridad

COPY deploy/aws/php-produccion.ini /usr/local/etc/php/conf.d/zz-moderniza.ini
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Dependencias PHP desde composer.lock (versiones fijadas), sin las de desarrollo
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

# Código de la aplicación + recursos compilados en la etapa 1
COPY . .
COPY --from=assets /app/public/build ./public/build
RUN composer dump-autoload --optimize --no-dev --no-scripts \
    && php artisan package:discover \
    && chown -R www-data:www-data storage bootstrap/cache

COPY deploy/aws/entrypoint.sh /usr/local/bin/moderniza-entrypoint
RUN chmod +x /usr/local/bin/moderniza-entrypoint

EXPOSE 80
ENTRYPOINT ["moderniza-entrypoint"]
CMD ["apache2-foreground"]

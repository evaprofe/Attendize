#!/bin/sh
# Arranque del contenedor de producción (Tarea 5).
# La configuración llega por variables de entorno (.env.production); no hay .env en la imagen.
set -e
cd /var/www/html

if [ -z "$APP_KEY" ]; then
  echo "ERROR: falta APP_KEY. Genera .env.production con generar-env.sh" >&2
  exit 1
fi

# Cachés de producción: se generan al arrancar porque dependen del entorno.
php artisan config:cache
php artisan route:cache
php artisan view:cache
# Apache (www-data) debe poder escribir sesiones y cachés
chown -R www-data:www-data storage bootstrap/cache

# Las migraciones NO se lanzan solas: se ejecutan una vez y de forma controlada
#   docker compose -f compose.aws.yml exec moderniza php artisan migrate --force
exec "$@"

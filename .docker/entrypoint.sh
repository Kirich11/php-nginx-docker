#!/usr/bin/env sh

set -e

# Runs application with nginx and FPM and makes some preparations for laravel application
# folders structure, permissions, etc.
run_application() {
  echo Give permissions to www-data to mounted volume directories
  chown -R www-data: /home/www-data/public /home/www-data/storage
  echo "Check nginx is fine"
  nginx -t
  echo "Run artisan migrations"
  php artisan migrate --force
  echo "Link artisan storage event if it's been already linked and suppress all errors"
  php artisan storage:link 2>/dev/null
  echo "Run FPM"
  php-fpm
  echo "Run NGINX as root process"
  nginx
}

if [[ "$APP_ENV" != "local" ]]; then
  echo "Cache application configuration..."
  # Caching everything for laravel in non-production mode
#  (php artisan config:cache && php artisan view:cache)
fi

if [[ "$CONTAINER_ROLE" == "app" ]]; then
  echo "Bootstraping application..."
  # If running app container we'll run nginx and all that stuff
  run_application

elif [[ "$CONTAINER_ROLE" == "scheduler" ]]; then

  echo "Running scheduler..."
  # If running scheduler container we'll run infinite loop with 60 seconds timeout
  # and artisan schedule command each minute
  while :
  do
    gosu www-data php artisan schedule:run --verbose --no-interaction &
    sleep 60
  done

elif [[ "$CONTAINER_ROLE" == "queue" ]]; then

  echo "Running queue..."
  while :
  do
    gosu www-data php artisan queue:work --verbose \
    --tries $QUEUE_TRIES \
    --timeout $QUEUE_TIMEOUT \
    --sleep $QUEUE_SLEEP_SECONDS \
    --delay $QUEUE_DELAY
  done

else
  echo "No matched action for given container role [$CONTAINER_ROLE]"
  exit 1
fi

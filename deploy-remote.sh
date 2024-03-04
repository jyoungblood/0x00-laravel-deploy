#!/bin/bash

GIT_BRANCH="main"
COMPOSER_PATH="/opt/cpanel/composer/bin/composer"
PHP_PATH="/usr/local/bin/php"


if getopts "e:" arg; then

  echo "## Taking site offline"
  cd laravel/$OPTARG
  $PHP_PATH artisan down --refresh=20

  echo "## Fetching source"
  git pull origin $GIT_BRANCH

  echo "## Installing dependencies"
  $COMPOSER_PATH install --no-interaction --prefer-dist --optimize-autoloader --no-dev
  echo "✅"

  echo "## Running migrations"
  $PHP_PATH artisan migrate
  echo "✅"

  echo "## Updating caches"
  $PHP_PATH artisan config:clear
  $PHP_PATH artisan route:clear
  $PHP_PATH artisan view:clear
  $PHP_PATH artisan config:cache
  $PHP_PATH artisan route:cache
  $PHP_PATH artisan view:cache
  echo "✅"

  echo "## Brining site online"
  $PHP_PATH artisan up

  echo "✅ Process complete"
  echo ""
  echo "(っ◕‿◕)っ ♥"
  echo ""

  exit
else
  echo "ERROR: no environment specified"
  exit
fi
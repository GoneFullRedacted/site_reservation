# =====================================
# DOCKERFILE POUR L'APPLICATION PHP
# =====================================

# Dockerfile
FROM php:8.2-apache

# Installation des extensions PHP nécessaires
RUN apt-get update && apt-get install -y \
    libpq-dev \
    && docker-php-ext-install pdo pdo_pgsql

# Activation du module Apache rewrite pour les URLs propres
RUN a2enmod rewrite

# Copie du code source dans le conteneur
COPY ./src /var/www/html/

# Permissions pour Apache
RUN chown -R www-data:www-data /var/www/html/
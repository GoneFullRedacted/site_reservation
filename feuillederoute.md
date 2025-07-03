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

# =====================================
# DOCKER-COMPOSE.YML - ORCHESTRATION
# =====================================

# docker-compose.yml
version: '3.8'

services:
  # Service Web (Apache + PHP)
  web:
    build: .
    container_name: reservation_web
    ports:
      - "8080:80"
    volumes:
      - ./src:/var/www/html
      - ./apache-config:/etc/apache2/sites-available
    depends_on:
      - db
    environment:
      - DB_HOST=db
      - DB_NAME=reservation_db
      - DB_USER=reservation_user
      - DB_PASSWORD=secure_password
    networks:
      - reservation_network

  # Service Base de données PostgreSQL
  db:
    image: postgres:15
    container_name: reservation_db
    environment:
      POSTGRES_DB: reservation_db
      POSTGRES_USER: reservation_user
      POSTGRES_PASSWORD: secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - reservation_network

  # Service PHPMyAdmin-like pour PostgreSQL (pgAdmin)
  pgadmin:
    image: dpage/pgadmin4
    container_name: reservation_pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin
    ports:
      - "8081:80"
    depends_on:
      - db
    networks:
      - reservation_network

# Volumes persistants
volumes:
  postgres_data:

# Réseau custom
networks:
  reservation_network:
    driver: bridge

# =====================================
# STRUCTURE DES DOSSIERS
# =====================================

# Structure recommandée du projet :
# 
# reservation-site/
# ├── Dockerfile
# ├── docker-compose.yml
# ├── init.sql
# ├── apache-config/
# │   └── 000-default.conf
# └── src/
#     ├── index.php
#     ├── config/
#     │   └── database.php
#     ├── assets/
#     │   ├── css/
#     │   │   └── style.css
#     │   └── js/
#     │       └── script.js
#     ├── pages/
#     │   ├── events.php
#     │   ├── reservation.php
#     │   └── admin.php
#     └── includes/
#         ├── header.php
#         ├── footer.php
#         └── functions.php

# =====================================
# CONFIGURATION APACHE
# =====================================

# apache-config/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Logs
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    
    # Configuration pour les fichiers statiques
    <LocationMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg)$">
        ExpiresActive On
        ExpiresDefault "access plus 1 month"
    </LocationMatch>
</VirtualHost>

# =====================================
# SCRIPT D'INITIALISATION BDD
# =====================================

# init.sql
-- Création des tables pour le système de réservation

-- Table des événements
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_date DATE NOT NULL,
    event_time TIME NOT NULL,
    location VARCHAR(255) NOT NULL,
    max_participants INTEGER NOT NULL,
    current_participants INTEGER DEFAULT 0,
    price DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des utilisateurs
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des réservations
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    event_id INTEGER REFERENCES events(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    number_of_people INTEGER NOT NULL DEFAULT 1,
    total_price DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'confirmed',
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    special_requests TEXT
);

-- Table des catégories d'événements
CREATE TABLE event_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(7) DEFAULT '#3498db'
);

-- Table de liaison événements-catégories
CREATE TABLE event_category_links (
    event_id INTEGER REFERENCES events(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES event_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, category_id)
);

-- Insertion de données d'exemple
INSERT INTO event_categories (name, description, color) VALUES
('Concert', 'Événements musicaux', '#e74c3c'),
('Sport', 'Événements sportifs', '#2ecc71'),
('Culture', 'Événements culturels', '#9b59b6'),
('Gastronomie', 'Événements culinaires', '#f39c12');

INSERT INTO events (title, description, event_date, event_time, location, max_participants, price) VALUES
('Festival de Jazz', 'Soirée jazz avec des artistes locaux', '2025-08-15', '20:00:00', 'Place de la Mairie', 200, 15.00),
('Match de Football', 'Match amical équipe locale', '2025-08-20', '15:00:00', 'Stade Municipal', 500, 8.00),
('Exposition d''Art', 'Exposition d''artistes contemporains', '2025-08-25', '10:00:00', 'Galerie Municipale', 50, 0.00);

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pour la table events
CREATE TRIGGER update_events_updated_at 
    BEFORE UPDATE ON events 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

# =====================================
# FICHIER DE CONFIGURATION PHP
# =====================================

# src/config/database.php
<?php
class Database {
    private $host;
    private $db_name;
    private $username;
    private $password;
    private $connection;
    
    public function __construct() {
        $this->host = $_ENV['DB_HOST'] ?? 'localhost';
        $this->db_name = $_ENV['DB_NAME'] ?? 'reservation_db';
        $this->username = $_ENV['DB_USER'] ?? 'reservation_user';
        $this->password = $_ENV['DB_PASSWORD'] ?? 'secure_password';
    }
    
    public function connect() {
        $this->connection = null;
        
        try {
            $dsn = "pgsql:host=" . $this->host . ";dbname=" . $this->db_name;
            $this->connection = new PDO($dsn, $this->username, $this->password);
            $this->connection->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->connection->exec("set names utf8");
        } catch(PDOException $e) {
            echo "Erreur de connexion: " . $e->getMessage();
        }
        
        return $this->connection;
    }
}
?>

# =====================================
# FICHIER .ENV (OPTIONNEL)
# =====================================

# .env
DB_HOST=db
DB_NAME=reservation_db
DB_USER=reservation_user
DB_PASSWORD=secure_password
APP_ENV=development
APP_DEBUG=true

# =====================================
# FICHIER .DOCKERIGNORE
# =====================================

# .dockerignore
.git
.gitignore
README.md
.env
.DS_Store
node_modules
*.log

# =====================================
# COMMANDES DOCKER ESSENTIELLES
# =====================================

# Commandes pour démarrer le projet :

# 1. Construire et démarrer tous les services
docker-compose up -d --build

# 2. Voir les logs
docker-compose logs -f

# 3. Arrêter les services
docker-compose down

# 4. Arrêter et supprimer les volumes (ATTENTION: supprime les données)
docker-compose down -v

# 5. Entrer dans le conteneur web
docker exec -it reservation_web bash

# 6. Entrer dans le conteneur de base de données
docker exec -it reservation_db psql -U reservation_user -d reservation_db

# 7. Voir l'état des conteneurs
docker-compose ps

# 8. Redémarrer un service spécifique
docker-compose restart web

# =====================================
# MAKEFILE POUR SIMPLIFIER LES COMMANDES
# =====================================

# Makefile
.PHONY: up down build logs clean restart

# Démarrer l'environnement
up:
	docker-compose up -d

# Arrêter l'environnement
down:
	docker-compose down

# Construire et démarrer
build:
	docker-compose up -d --build

# Voir les logs
logs:
	docker-compose logs -f

# Nettoyer complètement
clean:
	docker-compose down -v --rmi all

# Redémarrer
restart:
	docker-compose restart

# Entrer dans le conteneur web
shell:
	docker exec -it reservation_web bash

# Backup de la base de données
backup:
	docker exec reservation_db pg_dump -U reservation_user reservation_db > backup_$(shell date +%Y%m%d_%H%M%S).sql
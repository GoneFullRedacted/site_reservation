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
#!/bin/bash
set -e

# Prompt for confirmation
read -p "Are you sure you want to cleanup? This will delete all data and configuration. (y/n): " confirm
if [ "$confirm" != "y" ]; then
    exit 1
fi

# Stop and remove all containers
echo "================================================================="
echo "Stopping and removing all containers..."
echo "================================================================="
docker compose down -v --remove-orphans
echo "All containers stopped."
echo ""

# Remove all images
echo "================================================================="
echo "Removing docker images..."
echo "================================================================="
docker compose images -q | grep -v '^$' | xargs -r docker rmi --force
echo "All docker images removed."
echo ""

# Remove all data except the .gitkeep
echo "================================================================="
echo "Removing all data except the .gitkeep..."
echo "================================================================="
rm -rf data/caddy data/synapse data/postgres data/synapse-admin data/hookshot backups/postgres_*
echo "All data removed."
echo ""

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
echo ""

# Remove all images
echo "================================================================="
echo "Removing docker images..."
echo "================================================================="
docker compose images -q | grep -v '^$' | xargs -r docker rmi --force
echo ""

# Remove all data except the .gitkeep
echo "================================================================="
echo "Removing all data except the .gitkeep..."
echo "================================================================="
rm -rf data/caddy data/synapse data/postgres data/synapse-admin backups/postgres_*
echo ""

# Remove shared network if it exists
echo "================================================================="
echo "Removing shared network 'shared_network'..."
echo "================================================================="
if docker network inspect shared_network >/dev/null 2>&1; then
    echo "Removing shared network 'shared_network'..."
    docker network rm shared_network
else
    echo "Shared network 'shared_network' does not exist."
fi
echo ""

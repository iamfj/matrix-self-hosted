#!/bin/bash
set -e

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found."
    exit 1
fi

# Load environment variables
source .env

# Create backup of Postgres
echo "================================================================="
echo "Creating Postgres backup..."
echo "================================================================="
mkdir -p backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Check if postgres service is running
if [ -n "$(docker compose ps -q postgres 2>/dev/null)" ]; then
    echo "Dumping Postgres database..."
    # Use -T to disable TTY allocation for redirection
    # Pass PGPASSWORD to avoid prompt
    docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres pg_dumpall -U synapse --clean --if-exists > "backups/postgres_$TIMESTAMP.sql"
    echo "Backup saved to backups/postgres_$TIMESTAMP.sql"
else
    echo "Warning: Postgres container is not running. Skipping SQL dump."
    echo "Attempting raw file backup of data directory..."
    if [ -d "data/postgres" ]; then
        tar -czf "backups/postgres_data_$TIMESTAMP.tar.gz" data/postgres
        echo "Raw file backup saved to backups/postgres_data_$TIMESTAMP.tar.gz"
    fi
fi
echo ""

echo "================================================================="
echo "Pulling latest images..."
echo "================================================================="
docker compose pull
echo ""

echo "================================================================="
echo "Recreating containers..."
echo "================================================================="
docker compose up -d --wait
echo ""

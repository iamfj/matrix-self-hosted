#!/bin/bash
set -e

NEW_CONFIG_GENERATED=false

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Please copy the .env.example file to .env and fill in the values."
    exit 1
fi

# Load environment variables
source .env

# Create shared network if it doesn't exist
echo "================================================================="
echo "Creating shared network 'shared_network'..."
echo "================================================================="
if ! docker network inspect shared_network >/dev/null 2>&1; then
    docker network create shared_network
else
    echo "Shared network 'shared_network' already exists."
fi
echo ""

echo "================================================================="
echo "Generating new configuration..."
echo "================================================================="
if [ ! -f "data/synapse/homeserver.yaml" ]; then
    echo "Synapse configuration not found."
    docker compose run --rm -it --no-deps synapse generate
    NEW_CONFIG_GENERATED=true
else
    echo "Synapse configuration already exists. Skipping configuration generation."
fi
echo ""

# Check database configuration
if [ "$NEW_CONFIG_GENERATED" = true ] && grep -q "name: sqlite3" data/synapse/homeserver.yaml; then
    echo "================================================================="
    echo "Updating database configuration..."
    echo "================================================================="
    
    # Backup original config
    cp data/synapse/homeserver.yaml data/synapse/homeserver.yaml.bak
    
    # Replace sqlite database config with postgres
    # We use a temporary file to construct the new config safely
    cat > data/synapse/db_config.tmp <<EOF
database:
  name: psycopg2
  allow_unsafe_locale: true
  args:
    user: synapse
    password: ${POSTGRES_PASSWORD}
    database: synapse
    host: postgres
    cp_min: 5
    cp_max: 10
EOF

    # Remove the old database block (this is a simplified approach assuming standard block format)
    # A more robust way is using yq or similar, but we'll try sed/awk or just replace the whole block if predictable.
    # Since YAML structure varies, a simple replace for the default sqlite block is safest if we know what it looks like.
    # Default usually looks like:
    # database:
    #   name: sqlite3
    #   args:
    #     database: /data/homeserver.db
    
    # We will read the file, look for the database block and replace it.
    # However, without yq installed in the environment, text manipulation is risky.
    # Let's try a python one-liner which is likely available or just append/replace known strings.
    
    # Let's stick to a safer replacement of the specific sqlite lines if they match the default generation.
    
    sed -i.bak "/database:/,/database: \/data\/homeserver.db/c\\
database:\\
  name: psycopg2\\
  allow_unsafe_locale: true\\
  args:\\
    user: synapse\\
    password: ${POSTGRES_PASSWORD}\\
    database: synapse\\
    host: postgres\\
    cp_min: 5\\
    cp_max: 10" data/synapse/homeserver.yaml

    rm data/synapse/db_config.tmp

    echo ""
fi

# Generate synapse-admin config
echo "================================================================="
echo "Generating synapse-admin configuration..."
echo "================================================================="
mkdir -p data/synapse-admin
cat > data/synapse-admin/config.json <<EOF
{
  "restrictBaseUrl": "https://${SUBDOMAIN}.${DOMAIN_NAME}"
}
EOF
echo "Synapse-admin configuration generated."
echo ""

# Start the containers
echo "================================================================="
echo "Starting containers..."
echo "================================================================="
docker compose up -d --wait
echo ""

ADMIN_PASSWORD=""
if [ "$NEW_CONFIG_GENERATED" = true ]; then
    echo "================================================================="
    echo "Creating admin user..."
    echo "================================================================="

    # Generate a random password
    ADMIN_PASSWORD=$(openssl rand -base64 24)
    
    # Create the user
    # We remove -it since this is a script
    docker compose exec synapse register_new_matrix_user -u admin -p "$ADMIN_PASSWORD" --admin -c /data/homeserver.yaml http://localhost:8008
    
    if [ $? -eq 0 ]; then
        echo "Admin user created successfully."
    else
        echo "Failed to create admin user."
        ADMIN_PASSWORD=""
    fi
    echo ""
fi

# Display connection information
echo "\n================================================================="
echo "Matrix Synapse Server is running!"
echo "================================================================="
echo ""
echo "Server URL: https://${SUBDOMAIN}.${DOMAIN_NAME}"
echo "Admin UI:   https://admin.${SUBDOMAIN}.${DOMAIN_NAME}"
echo ""
echo "You can now connect to your server using a Matrix client like Element."
echo "When asked for a homeserver, enter: https://${SUBDOMAIN}.${DOMAIN_NAME}"

if [ -n "$ADMIN_PASSWORD" ]; then
    echo ""
    echo "-----------------------------------------------------------------"
    echo "IMPORTANT: An admin user has been created automatically."
    echo "Username: admin"
    echo "Password: $ADMIN_PASSWORD"
    echo ""
    echo "NOTE: This information will only be displayed ONCE. Please save it now."
    echo "-----------------------------------------------------------------"
else
    echo ""
    echo "To create a user, you can run:"
    echo "./create_user.sh"
fi

echo ""

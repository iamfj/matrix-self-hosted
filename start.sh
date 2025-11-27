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
    echo "Shared network 'shared_network' created."
else
    echo "Shared network 'shared_network' already exists."
fi
echo ""

echo "================================================================="
echo "Setup Synapse..."
echo "================================================================="
if [ ! -f "data/synapse/homeserver.yaml" ]; then
    echo "Synapse configuration not found. Generating new configuration..."
    docker compose run --rm -it --no-deps synapse generate
    echo "Synapse configuration generated."
    NEW_CONFIG_GENERATED=true
else
    echo "Synapse configuration already exists. Skipping configuration generation."
fi
echo ""

# Check database configuration
if [ "$NEW_CONFIG_GENERATED" = true ] && grep -q "name: sqlite3" data/synapse/homeserver.yaml; then
    echo "Detected SQLite database configuration. Updating to PostgreSQL..."
    
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

    echo "Database configuration updated."
    echo "Configuration backup saved to data/synapse/homeserver.yaml.bak"
    echo ""
fi

# Generate synapse-admin config
echo "================================================================="
echo "Setup Synapse Admin..."
echo "================================================================="
mkdir -p data/synapse-admin
cat > data/synapse-admin/config.json <<EOF
{
  "restrictBaseUrl": "https://${SUBDOMAIN}.${DOMAIN_NAME}"
}
EOF
echo "Synapse-admin configuration generated."
echo ""

# Hookshot Setup
echo "================================================================="
echo "Setup Hookshot..."
echo "================================================================="

# Generate config.yaml if missing
if [ ! -f "data/hookshot/config.yaml" ]; then
    mkdir -p data/hookshot
    cat > data/hookshot/config.yaml <<EOF
bridge:
  domain: ${SUBDOMAIN}.${DOMAIN_NAME}
  url: http://hookshot:9993
  mediaUrl: https://${SUBDOMAIN}.${DOMAIN_NAME}
  port: 9993
  bindAddress: 0.0.0.0

logging:
  level: info
  colorize: false
  json: false
  timestampFormat: HH:mm:ss:SSS

cache:
  redisUri: "redis://valkey:3679"

homeserver:
  url: http://synapse:8008
  domain: ${SUBDOMAIN}.${DOMAIN_NAME}

listeners:
  - port: 9000
    bindAddress: 0.0.0.0
    resources:
      - webhooks
  - port: 9001
    bindAddress: 127.0.0.1
    resources:
      - metrics
  - port: 9002
    bindAddress: 0.0.0.0
    resources:
      - widgets

permissions:
  - actor: ${SUBDOMAIN}.${DOMAIN_NAME}
    services:
      - service: "*"
        level: admin

widgets:
  addToAdminRooms: false
  disallowedIpRanges:
    - 127.0.0.0/8
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - 100.64.0.0/10
    - 192.0.0.0/24
    - 169.254.0.0/16
    - 192.88.99.0/24
    - 198.18.0.0/15
    - 192.0.2.0/24
    - 198.51.100.0/24
    - 203.0.113.0/24
    - 224.0.0.0/4
    - ::1/128
    - fe80::/10
    - fc00::/7
    - 2001:db8::/32
    - ff00::/8
    - fec0::/10
  roomSetupWidget:
    addOnInvite: false
  publicUrl: https://${SUBDOMAIN}.${DOMAIN_NAME}/widgetapi/v1/static
  branding:
    widgetTitle: Hookshot Configuration
EOF
    echo "Hookshot config.yaml generated."
else
    echo "Hookshot config.yaml already exists. Skipping generation."
fi

echo ""

# Start the stack
echo "================================================================="
echo "Starting stack..."
echo "================================================================="
docker compose up -d --wait
echo ""

ADMIN_PASSWORD=""
if [ "$NEW_CONFIG_GENERATED" = true ]; then
    echo "Detected fresh installation. Creating admin user..."

    # Generate a random password
    ADMIN_PASSWORD=$(openssl rand -base64 24)
    
    # Create the user
    # We remove -it since this is a script
    docker compose exec synapse register_new_matrix_user -u admin -p "$ADMIN_PASSWORD" --admin -c /data/homeserver.yaml http://localhost:8008
    echo "Admin user created successfully."
    echo ""
fi

# Display connection information
echo "\n================================================================="
echo "Matrix Synapse Server is running!"
echo "================================================================="
echo ""
echo "Server URL: https://${SUBDOMAIN}.${DOMAIN_NAME}"
echo "Admin UI:   https://admin.${SUBDOMAIN}.${DOMAIN_NAME}"
echo "Hookshot:   https://hookshot.${SUBDOMAIN}.${DOMAIN_NAME}"
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

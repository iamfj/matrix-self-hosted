#!/bin/bash
set -e

if [ ! -f ".env" ]; then
    echo "Please copy the .env.example file to .env and fill in the values."
    exit 1
fi

# Prompt for username
read -p "Enter username: " username

if [ -z "$username" ]; then
    echo "Error: Username cannot be empty."
    exit 1
fi

# Prompt for password
read -s -p "Enter password: " password
echo ""
read -s -p "Confirm password: " password_confirm
echo ""

if [ "$password" != "$password_confirm" ]; then
    echo "Error: Passwords do not match."
    exit 1
fi

if [ -z "$password" ]; then
    echo "Error: Password cannot be empty."
    exit 1
fi

# Prompt for admin privileges
read -p "Make this user an admin? (y/n): " is_admin

ADMIN_FLAG=""
if [ "$is_admin" = "y" ] || [ "$is_admin" = "Y" ]; then
    ADMIN_FLAG="--admin"
else
    ADMIN_FLAG="--no-admin"
fi

echo "Creating user '$username'..."

# Execute the creation command in the container
# We assume the container is running. If not, this will fail.
docker compose exec synapse register_new_matrix_user \
    -u "$username" \
    -p "$password" \
    $ADMIN_FLAG \
    -c /data/homeserver.yaml \
    http://localhost:8008

if [ $? -eq 0 ]; then
    echo "User '$username' created successfully."
else
    echo "Failed to create user."
fi

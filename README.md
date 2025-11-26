# Matrix Self-Hosted

A robust, self-hosted Matrix Synapse server setup using Docker Compose, Caddy (as a reverse proxy with automatic HTTPS), and PostgreSQL. This project includes a suite of management scripts to simplify deployment, maintenance, and user management.

## Features

*   **Synapse**: The reference homeserver implementation for Matrix.
*   **Synapse Admin**: A web-based administration interface for managing users, rooms, and server settings.
*   **PostgreSQL**: A powerful, open-source object-relational database system used as the backend for Synapse.
*   **Caddy**: A modern web server that handles reverse proxying and automatic SSL/TLS certificate management (Let's Encrypt).
*   **Automated Setup**: The start script handles configuration generation and updates Synapse to use PostgreSQL automatically.
*   **Management Tools**: Helper scripts for starting, stopping, updating, backing up, and managing users.

## Prerequisites

*   [Docker](https://docs.docker.com/get-docker/)
*   [Docker Compose](https://docs.docker.com/compose/install/)
*   A domain name with the following DNS records pointing to your server's IP:
    *   **Matrix Server**: `SUBDOMAIN.DOMAIN_NAME` (e.g., `matrix.example.com`)
    *   **Admin UI**: `admin.SUBDOMAIN.DOMAIN_NAME` (e.g., `admin.matrix.example.com`)

## Installation & Setup

1.  **Clone the repository** (or download the files to your server).

2.  **Configure Environment Variables**:
    Copy the provided example configuration file:
    
    ```bash
    cp .env.example .env
    ```

    Open `.env` and update the values:

    ```env
    # Database Configuration
    POSTGRES_PASSWORD=change_this_to_a_secure_password
    
    # Domain Configuration
    SUBDOMAIN=matrix
    DOMAIN_NAME=example.com
    
    # Caddy / SSL Configuration
    CADDY_VERSION=latest
    SSL_EMAIL=your-email@example.com
    ```

    > **Note**: Replace `change_this_to_a_secure_password`, `example.com`, and `your-email@example.com` with your actual values.

3.  **Start the Server**:
    Run the initialization script. This will set up the network, generate configurations, and start the services.

    ```bash
    ./start.sh
    ```

    **On the first run**, this script will:
    *   Generate the Synapse `homeserver.yaml` configuration.
    *   Automatically reconfigure Synapse to use PostgreSQL instead of the default SQLite.
    *   Create an **Admin User** and display the login credentials. **Save these credentials immediately**, as they are shown only once.

## Usage

### Service Management

*   **Start Services**:
    ```bash
    ./start.sh
    ```
    Starts all containers and ensures the network and configurations are in place.

*   **Stop Services**:
    ```bash
    ./stop.sh
    ```
    Stops all running containers.

*   **Restart Services**:
    ```bash
    ./restart.sh
    ```
    Stops and then immediately starts the containers.

### User Management

*   **Create a New User**:
    ```bash
    ./create_user.sh
    ```
    An interactive script that prompts for a username and password. You can choose to create a regular user or a server administrator.
    > **Note**: The server must be running for this script to work.

### Maintenance & Updates

*   **Update System**:
    ```bash
    ./update.sh
    ```
    This script performs a safe update procedure:
    1.  Creates a backup of the PostgreSQL database (saved in `backups/`).
    2.  Pulls the latest Docker images for all services.
    3.  Recreates the containers with the new images.

*   **Full Reset / Cleanup**:
    ```bash
    ./cleanup.sh
    ```
    **⚠️ WARNING**: This is a destructive action. It will:
    *   Stop and remove all containers.
    *   Remove the Docker images.
    *   **Delete all data** in `data/` (database, media, configuration).
    *   **Delete backups** matching `backups/postgres_*`.
    *   Remove the Docker network.

## Directory Structure

*   `config/`: Contains the Caddy configuration (`Caddyfile`).
*   `data/`: Stores persistent data.
    *   `caddy/`: SSL certificates and Caddy data.
    *   `postgres/`: PostgreSQL database files.
    *   `synapse/`: Synapse configuration (`homeserver.yaml`), media store, and logs.
*   `backups/`: Stores database backups created by the `update.sh` script.

## Accessing Your Server

Once the server is running, your services will be accessible at:

*   **Matrix Homeserver**: `https://<SUBDOMAIN>.<DOMAIN_NAME>` (e.g., `https://matrix.example.com`)
*   **Admin UI**: `https://admin.<SUBDOMAIN>.<DOMAIN_NAME>` (e.g., `https://admin.matrix.example.com`)

You can connect to your homeserver using any Matrix client (like [Element](https://element.io/)) by entering your custom homeserver URL during login.


#!/bin/bash

# Docker Template Generator
# A tool for generating common Docker Compose templates
# Author: Claude

# Configuration
TEMPLATES_DIR="$HOME/docker/templates"
DOCKER_BASE_DIR="$HOME/docker"
STACKS_DIR="$DOCKER_BASE_DIR/stacks"
CONFIGS_DIR="$DOCKER_BASE_DIR/configs"
DATA_DIR="$DOCKER_BASE_DIR/data"

# Create directories if they don't exist
mkdir -p "$TEMPLATES_DIR" "$STACKS_DIR" "$CONFIGS_DIR" "$DATA_DIR"

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Show available templates
show_templates() {
    echo -e "${BLUE}Available templates:${NC}"
    echo "1. Web Server (Nginx)"
    echo "2. Database (MariaDB/MySQL)"
    echo "3. Database (PostgreSQL)"
    echo "4. WordPress"
    echo "5. LAMP Stack"
    echo "6. Monitoring Stack (Prometheus + Grafana)"
    echo "7. Reverse Proxy (Traefik)"
    echo "8. Media Server (Plex)"
    echo "9. NodeJS Application"
    echo "10. Python Flask Application"
}

# Create Nginx template
create_nginx_template() {
    local stack_name="$1"
    local http_port="${2:-80}"
    local https_port="${3:-443}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$CONFIGS_DIR/$stack_name/nginx/conf.d"
    mkdir -p "$DATA_DIR/$stack_name/www/html"

    # Create default index.html
    cat > "$DATA_DIR/$stack_name/www/html/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $stack_name</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 30px;
            text-align: center;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Welcome to $stack_name</h1>
    <p>If you see this page, the nginx web server is successfully installed and working.</p>
</body>
</html>
EOF

    # Create default nginx config
    cat > "$CONFIGS_DIR/$stack_name/nginx/conf.d/default.conf" << EOF
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  nginx:
    image: nginx:latest
    container_name: ${stack_name}_nginx
    restart: unless-stopped
    ports:
      - "$http_port:80"
      - "$https_port:443"
    volumes:
      - $CONFIGS_DIR/$stack_name/nginx/conf.d:/etc/nginx/conf.d
      - $DATA_DIR/$stack_name/www/html:/usr/share/nginx/html
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    echo -e "${GREEN}Nginx template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Config directory: $CONFIGS_DIR/$stack_name"
    echo "Data directory: $DATA_DIR/$stack_name"
}

# Create MariaDB/MySQL template
create_mysql_template() {
    local stack_name="$1"
    local db_port="${2:-3306}"
    local db_root_password="${3:-mysecretpassword}"
    local db_name="${4:-mydatabase}"
    local db_user="${5:-dbuser}"
    local db_password="${6:-dbuserpassword}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$DATA_DIR/$stack_name/db"

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  db:
    image: mariadb:latest
    container_name: ${stack_name}_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $db_root_password
      MYSQL_DATABASE: $db_name
      MYSQL_USER: $db_user
      MYSQL_PASSWORD: $db_password
    volumes:
      - $DATA_DIR/$stack_name/db:/var/lib/mysql
    ports:
      - "$db_port:3306"
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create .env file
    cat > "$STACKS_DIR/$stack_name/.env" << EOF
# Database Configuration
DB_ROOT_PASSWORD=$db_root_password
DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
EOF

    echo -e "${GREEN}MariaDB/MySQL template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Data directory: $DATA_DIR/$stack_name/db"
    echo -e "${BLUE}Note: Database credentials are stored in .env file. Keep this secure!${NC}"
}

# Create PostgreSQL template
create_postgres_template() {
    local stack_name="$1"
    local db_port="${2:-5432}"
    local db_user="${3:-postgres}"
    local db_password="${4:-postgres}"
    local db_name="${5:-postgres}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$DATA_DIR/$stack_name/db"

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  db:
    image: postgres:latest
    container_name: ${stack_name}_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: $db_user
      POSTGRES_PASSWORD: $db_password
      POSTGRES_DB: $db_name
    volumes:
      - $DATA_DIR/$stack_name/db:/var/lib/postgresql/data
    ports:
      - "$db_port:5432"
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create .env file
    cat > "$STACKS_DIR/$stack_name/.env" << EOF
# Database Configuration
POSTGRES_USER=$db_user
POSTGRES_PASSWORD=$db_password
POSTGRES_DB=$db_name
EOF

    echo -e "${GREEN}PostgreSQL template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Data directory: $DATA_DIR/$stack_name/db"
    echo -e "${BLUE}Note: Database credentials are stored in .env file. Keep this secure!${NC}"
}

# Create WordPress template
create_wordpress_template() {
    local stack_name="$1"
    local http_port="${2:-80}"
    local db_root_password="${3:-rootpassword}"
    local db_name="${4:-wordpress}"
    local db_user="${5:-wordpress}"
    local db_password="${6:-wordpress}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$DATA_DIR/$stack_name/db"
    mkdir -p "$DATA_DIR/$stack_name/wordpress"

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  db:
    image: mariadb:latest
    container_name: ${stack_name}_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $db_root_password
      MYSQL_DATABASE: $db_name
      MYSQL_USER: $db_user
      MYSQL_PASSWORD: $db_password
    volumes:
      - $DATA_DIR/$stack_name/db:/var/lib/mysql
    networks:
      - ${stack_name}_network

  wordpress:
    image: wordpress:latest
    container_name: ${stack_name}_wordpress
    restart: unless-stopped
    depends_on:
      - db
    ports:
      - "$http_port:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: $db_name
      WORDPRESS_DB_USER: $db_user
      WORDPRESS_DB_PASSWORD: $db_password
    volumes:
      - $DATA_DIR/$stack_name/wordpress:/var/www/html
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create .env file
    cat > "$STACKS_DIR/$stack_name/.env" << EOF
# WordPress Configuration
MYSQL_ROOT_PASSWORD=$db_root_password
MYSQL_DATABASE=$db_name
MYSQL_USER=$db_user
MYSQL_PASSWORD=$db_password
EOF

    echo -e "${GREEN}WordPress template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Data directories:"
    echo "  - $DATA_DIR/$stack_name/db (database)"
    echo "  - $DATA_DIR/$stack_name/wordpress (WordPress files)"
    echo -e "${BLUE}Note: Database credentials are stored in .env file. Keep this secure!${NC}"
}

# Create LAMP Stack template
create_lamp_template() {
    local stack_name="$1"
    local http_port="${2:-80}"
    local db_root_password="${3:-rootpassword}"
    local db_name="${4:-mydb}"
    local db_user="${5:-dbuser}"
    local db_password="${6:-dbpassword}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$CONFIGS_DIR/$stack_name/php"
    mkdir -p "$DATA_DIR/$stack_name/db"
    mkdir -p "$DATA_DIR/$stack_name/www/html"

    # Create default index.php
    cat > "$DATA_DIR/$stack_name/www/html/index.php" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>LAMP Stack - $stack_name</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 30px;
            text-align: center;
        }
        h1 {
            color: #333;
        }
        .info {
            background: #f4f4f4;
            padding: 20px;
            margin: 20px auto;
            max-width: 600px;
            border-radius: 5px;
            text-align: left;
        }
    </style>
</head>
<body>
    <h1>LAMP Stack - $stack_name</h1>
    <div class="info">
        <h2>PHP Information:</h2>
        <?php
        phpinfo();
        ?>
    </div>
</body>
</html>
EOF

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  www:
    image: php:8.0-apache
    container_name: ${stack_name}_www
    restart: unless-stopped
    ports:
      - "$http_port:80"
    volumes:
      - $DATA_DIR/$stack_name/www/html:/var/www/html
    depends_on:
      - db
    networks:
      - ${stack_name}_network

  db:
    image: mariadb:latest
    container_name: ${stack_name}_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $db_root_password
      MYSQL_DATABASE: $db_name
      MYSQL_USER: $db_user
      MYSQL_PASSWORD: $db_password
    volumes:
      - $DATA_DIR/$stack_name/db:/var/lib/mysql
    networks:
      - ${stack_name}_network

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: ${stack_name}_phpmyadmin
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: $db_root_password
    depends_on:
      - db
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create .env file
    cat > "$STACKS_DIR/$stack_name/.env" << EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=$db_root_password
MYSQL_DATABASE=$db_name
MYSQL_USER=$db_user
MYSQL_PASSWORD=$db_password
EOF

    echo -e "${GREEN}LAMP Stack template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Data directories:"
    echo "  - $DATA_DIR/$stack_name/db (database)"
    echo "  - $DATA_DIR/$stack_name/www/html (web files)"
    echo -e "${BLUE}Note: Database credentials are stored in .env file. Keep this secure!${NC}"
    echo "Access phpMyAdmin at: http://localhost:8080"
}

# Create Monitoring Stack template (Prometheus + Grafana)
create_monitoring_template() {
    local stack_name="$1"
    local grafana_port="${2:-3000}"
    local prometheus_port="${3:-9090}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$CONFIGS_DIR/$stack_name/prometheus"
    mkdir -p "$DATA_DIR/$stack_name/prometheus"
    mkdir -p "$DATA_DIR/$stack_name/grafana"

    # Create prometheus.yml config
    cat > "$CONFIGS_DIR/$stack_name/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: ${stack_name}_prometheus
    restart: unless-stopped
    ports:
      - "$prometheus_port:9090"
    volumes:
      - $CONFIGS_DIR/$stack_name/prometheus:/etc/prometheus
      - $DATA_DIR/$stack_name/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    networks:
      - ${stack_name}_network

  grafana:
    image: grafana/grafana:latest
    container_name: ${stack_name}_grafana
    restart: unless-stopped
    ports:
      - "$grafana_port:3000"
    volumes:
      - $DATA_DIR/$stack_name/grafana:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - ${stack_name}_network

  node-exporter:
    image: prom/node-exporter:latest
    container_name: ${stack_name}_node_exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - ${stack_name}_network

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: ${stack_name}_cadvisor
    restart: unless-stopped
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    echo -e "${GREEN}Monitoring Stack template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Config directory: $CONFIGS_DIR/$stack_name/prometheus"
    echo "Data directories:"
    echo "  - $DATA_DIR/$stack_name/prometheus"
    echo "  - $DATA_DIR/$stack_name/grafana"
    echo "Access Grafana at: http://localhost:$grafana_port"
    echo "Access Prometheus at: http://localhost:$prometheus_port"
}

# Create Traefik Reverse Proxy template
create_traefik_template() {
    local stack_name="$1"
    local http_port="${2:-80}"
    local https_port="${3:-443}"
    local dashboard_port="${4:-8080}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$CONFIGS_DIR/$stack_name/traefik"
    mkdir -p "$DATA_DIR/$stack_name/traefik"

    # Create traefik.yml config
    cat > "$CONFIGS_DIR/$stack_name/traefik/traefik.yml" << EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /etc/traefik/acme/acme.json
      httpChallenge:
        entryPoint: web
EOF

    # Create dynamic configuration
    mkdir -p "$CONFIGS_DIR/$stack_name/traefik/dynamic"
    cat > "$CONFIGS_DIR/$stack_name/traefik/dynamic/dashboard.yml" << EOF
http:
  routers:
    dashboard:
      rule: Host(`traefik.localhost`)
      service: api@internal
      middlewares:
        - auth
  middlewares:
    auth:
      basicAuth:
        users:
          - "admin:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/"  # Password: admin
EOF

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  traefik:
    image: traefik:latest
    container_name: ${stack_name}_traefik
    restart: unless-stopped
    ports:
      - "$http_port:80"
      - "$https_port:443"
      - "$dashboard_port:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $CONFIGS_DIR/$stack_name/traefik/traefik.yml:/etc/traefik/traefik.yml
      - $CONFIGS_DIR/$stack_name/traefik/dynamic:/etc/traefik/dynamic
      - $DATA_DIR/$stack_name/traefik/acme:/etc/traefik/acme
    networks:
      - ${stack_name}_network
    labels:
      - "traefik.enable=true"

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create acme directory
    mkdir -p "$DATA_DIR/$stack_name/traefik/acme"
    touch "$DATA_DIR/$stack_name/traefik/acme/acme.json"
    chmod 600 "$DATA_DIR/$stack_name/traefik/acme/acme.json"

    echo -e "${GREEN}Traefik Reverse Proxy template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Config directory: $CONFIGS_DIR/$stack_name/traefik"
    echo "Data directory: $DATA_DIR/$stack_name/traefik"
    echo "Access Traefik Dashboard at: http://localhost:$dashboard_port or https://traefik.localhost"
    echo -e "${BLUE}Note: Default dashboard credentials are admin/admin${NC}"
}

# Create Plex Media Server template
create_plex_template() {
    local stack_name="$1"
    local web_port="${2:-32400}"
    local timezone="${3:-UTC}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$CONFIGS_DIR/$stack_name/plex"
    mkdir -p "$DATA_DIR/$stack_name/media/movies"
    mkdir -p "$DATA_DIR/$stack_name/media/tv"
    mkdir -p "$DATA_DIR/$stack_name/media/music"

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  plex:
    image: plexinc/pms-docker:latest
    container_name: ${stack_name}_plex
    restart: unless-stopped
    ports:
      - "$web_port:32400/tcp"
      - "3005:3005/tcp"
      - "8324:8324/tcp"
      - "32469:32469/tcp"
      - "1900:1900/udp"
      - "32410:32410/udp"
      - "32412:32412/udp"
      - "32413:32413/udp"
      - "32414:32414/udp"
    environment:
      - TZ=$timezone
      - PLEX_CLAIM=claim-XXXXXXXXXXXXXXXXXXXX  # Replace with your claim token from https://plex.tv/claim
      - ADVERTISE_IP=http://localhost:$web_port/
    volumes:
      - $CONFIGS_DIR/$stack_name/plex:/config
      - $DATA_DIR/$stack_name/media/movies:/data/movies
      - $DATA_DIR/$stack_name/media/tv:/data/tv
      - $DATA_DIR/$stack_name/media/music:/data/music
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    echo -e "${GREEN}Plex Media Server template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Config directory: $CONFIGS_DIR/$stack_name/plex"
    echo "Media directories:"
    echo "  - $DATA_DIR/$stack_name/media/movies"
    echo "  - $DATA_DIR/$stack_name/media/tv"
    echo "  - $DATA_DIR/$stack_name/media/music"
    echo -e "${BLUE}Note: Remember to update the PLEX_CLAIM token in the compose.yml file${NC}"
    echo "Access Plex at: http://localhost:$web_port/web"
}

# Create NodeJS Application template
create_nodejs_template() {
    local stack_name="$1"
    local app_port="${2:-3000}"
    local node_version="${3:-16}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$DATA_DIR/$stack_name/app"

    # Create a simple package.json
    cat > "$DATA_DIR/$stack_name/app/package.json" << EOF
{
  "name": "${stack_name}",
  "version": "1.0.0",
  "description": "Node.js Application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.1"
  },
  "devDependencies": {
    "nodemon": "^2.0.19"
  }
}
EOF

    # Create a simple server.js
    cat > "$DATA_DIR/$stack_name/app/server.js" << EOF
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.send('Hello from ${stack_name} Node.js Application!');
});

app.listen(PORT, () => {
  console.log(\`Server is running on port \${PORT}\`);
});
EOF

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  app:
    image: node:$node_version
    container_name: ${stack_name}_app
    restart: unless-stopped
    working_dir: /app
    ports:
      - "$app_port:3000"
    volumes:
      - $DATA_DIR/$stack_name/app:/app
    command: >
      bash -c "npm install &&
               npm start"
    environment:
      - NODE_ENV=production
      - PORT=3000
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create .dockerignore
    cat > "$DATA_DIR/$stack_name/app/.dockerignore" << EOF
node_modules
npm-debug.log
EOF

    echo -e "${GREEN}NodeJS Application template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Application directory: $DATA_DIR/$stack_name/app"
    echo "Access application at: http://localhost:$app_port"
}

# Create Python Flask Application template
create_flask_template() {
    local stack_name="$1"
    local app_port="${2:-5000}"
    local python_version="${3:-3.9}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$DATA_DIR/$stack_name/app"

    # Create a simple app.py
    cat > "$DATA_DIR/$stack_name/app/app.py" << EOF
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        'message': 'Hello from ${stack_name} Flask Application!',
        'status': 'running'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

    # Create requirements.txt
    cat > "$DATA_DIR/$stack_name/app/requirements.txt" << EOF
flask==2.0.1
gunicorn==20.1.0
EOF

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  app:
    image: python:$python_version
    container_name: ${stack_name}_app
    restart: unless-stopped
    working_dir: /app
    ports:
      - "$app_port:5000"
    volumes:
      - $DATA_DIR/$stack_name/app:/app
    command: >
      bash -c "pip install -r requirements.txt &&
               gunicorn --bind 0.0.0.0:5000 app:app"
    environment:
      - PYTHONUNBUFFERED=1
      - FLASK_APP=app.py
      - FLASK_ENV=production
    networks:
      - ${stack_name}_network

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    echo -e "${GREEN}Python Flask Application template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Application directory: $DATA_DIR/$stack_name/app"
    echo "Access application at: http://localhost:$app_port"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_templates
        echo
        echo "Usage: $0 <template-number> <stack-name> [options]"
        echo "Example: $0 1 mywebserver 8080 8443"
        exit 0
    fi

    template_number="$1"
    stack_name="$2"

    if [ -z "$stack_name" ]; then
        echo "Error: Stack name is required"
        echo "Usage: $0 <template-number> <stack-name> [options]"
        exit 1
    fi

    case $template_number in
        1)
            shift 2
            create_nginx_template "$stack_name" "$@"
            ;;
        2)
            shift 2
            create_mysql_template
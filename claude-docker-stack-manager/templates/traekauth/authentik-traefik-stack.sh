#!/bin/bash

# Create Authentik with Traefik template
create_authentik_template() {
    local stack_name="$1"
    local domain="${2:-authentik.localhost}"
    local traefik_http_port="${3:-80}"
    local traefik_https_port="${4:-443}"
    local postgres_password="${5:-postgres}"
    local authentik_secret_key="${6:-$(openssl rand -base64 36)}"

    mkdir -p "$STACKS_DIR/$stack_name"
    mkdir -p "$CONFIGS_DIR/$stack_name/traefik/dynamic"
    mkdir -p "$DATA_DIR/$stack_name/traefik/acme"
    mkdir -p "$DATA_DIR/$stack_name/authentik/{media,templates,certs}"
    mkdir -p "$DATA_DIR/$stack_name/postgresql"
    mkdir -p "$DATA_DIR/$stack_name/redis"

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
    http:
      tls:
        certResolver: letsencrypt

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: ${stack_name}_network
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

    # Create dynamic configuration for traefik dashboard
    cat > "$CONFIGS_DIR/$stack_name/traefik/dynamic/dashboard.yml" << EOF
http:
  routers:
    dashboard:
      rule: "Host(\`traefik.$domain\`)"
      service: api@internal
      entryPoints:
        - websecure
      tls: {}
      middlewares:
        - authentik@docker
EOF

    # Create touch acme.json and set proper permissions
    touch "$DATA_DIR/$stack_name/traefik/acme/acme.json"
    chmod 600 "$DATA_DIR/$stack_name/traefik/acme/acme.json"

    # Create docker-compose.yml
    cat > "$STACKS_DIR/$stack_name/compose.yml" << EOF
# Docker Compose configuration for '$stack_name'
# Created on $(date)
version: '3.8'

services:
  # Traefik - reverse proxy
  traefik:
    image: traefik:latest
    container_name: ${stack_name}_traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "$traefik_http_port:80"
      - "$traefik_https_port:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $CONFIGS_DIR/$stack_name/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - $CONFIGS_DIR/$stack_name/traefik/dynamic:/etc/traefik/dynamic:ro
      - $DATA_DIR/$stack_name/traefik/acme:/etc/traefik/acme
    networks:
      - ${stack_name}_network
    depends_on:
      - authentik-server
    labels:
      - "traefik.enable=true"

  # Authentik - database
  postgresql:
    image: postgres:15-alpine
    container_name: ${stack_name}_postgresql
    restart: unless-stopped
    environment:
      - POSTGRES_PASSWORD=${postgres_password}
      - POSTGRES_USER=authentik
      - POSTGRES_DB=authentik
    volumes:
      - $DATA_DIR/$stack_name/postgresql:/var/lib/postgresql/data
    networks:
      - ${stack_name}_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d authentik -U authentik"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 5s

  # Authentik - redis
  redis:
    image: redis:alpine
    container_name: ${stack_name}_redis
    restart: unless-stopped
    networks:
      - ${stack_name}_network
    volumes:
      - $DATA_DIR/$stack_name/redis:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 5s

  # Authentik - server
  authentik-server:
    image: ghcr.io/goauthentik/server:latest
    container_name: ${stack_name}_authentik_server
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: ${postgres_password}
      AUTHENTIK_SECRET_KEY: ${authentik_secret_key}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
      AUTHENTIK_PORT_HTTP: 9000
      AUTHENTIK_PORT_HTTPS: 9443
    volumes:
      - $DATA_DIR/$stack_name/authentik/media:/media
      - $DATA_DIR/$stack_name/authentik/templates:/templates
      - $DATA_DIR/$stack_name/authentik/certs:/certs
    ports:
      - "9000:9000"
      - "9443:9443"
    networks:
      - ${stack_name}_network
    depends_on:
      - postgresql
      - redis
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authentik.rule=Host(\`$domain\`)"
      - "traefik.http.routers.authentik.entrypoints=websecure"
      - "traefik.http.routers.authentik.tls=true"
      - "traefik.http.services.authentik.loadbalancer.server.port=9000"
      - "traefik.http.middlewares.authentik.forwardauth.address=http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
      - "traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true"
      - "traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid,X-authentik-jwt,X-authentik-meta-jwks,X-authentik-meta-outpost,X-authentik-meta-provider,X-authentik-meta-app,X-authentik-meta-version"

  # Authentik - worker
  authentik-worker:
    image: ghcr.io/goauthentik/server:latest
    container_name: ${stack_name}_authentik_worker
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: ${postgres_password}
      AUTHENTIK_SECRET_KEY: ${authentik_secret_key}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
    volumes:
      - $DATA_DIR/$stack_name/authentik/media:/media
      - $DATA_DIR/$stack_name/authentik/templates:/templates
      - $DATA_DIR/$stack_name/authentik/certs:/certs
    networks:
      - ${stack_name}_network
    depends_on:
      - postgresql
      - redis

networks:
  ${stack_name}_network:
    name: ${stack_name}_network
EOF

    # Create .env file
    cat > "$STACKS_DIR/$stack_name/.env" << EOF
# Authentik Configuration
DOMAIN=$domain
POSTGRES_PASSWORD=$postgres_password
AUTHENTIK_SECRET_KEY=$authentik_secret_key
EOF

    echo -e "${GREEN}Authentik with Traefik template created successfully for '$stack_name'${NC}"
    echo "Stack directory: $STACKS_DIR/$stack_name"
    echo "Config directory: $CONFIGS_DIR/$stack_name"
    echo "Data directories:"
    echo "  - $DATA_DIR/$stack_name/traefik"
    echo "  - $DATA_DIR/$stack_name/authentik"
    echo "  - $DATA_DIR/$stack_name/postgresql"
    echo "  - $DATA_DIR/$stack_name/redis"
    echo -e "${BLUE}Note: Generated secret keys are in the .env file. Keep this secure!${NC}"
    echo "Access Authentik at: https://$domain"
    echo "Access Traefik Dashboard at: https://traefik.$domain (protected by Authentik)"
    echo -e "${BLUE}Initial setup:${NC}"
    echo "1. Visit https://$domain to complete the Authentik setup"
    echo "2. After setup, configure an Outpost for Traefik integration"
    echo "3. Create providers and applications to protect your services"
}













# Update show_templates function to include the new Authentik template
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
    echo "11. Authentik with Traefik (Auth System)"
}

# Update the case statement in the main function
# Inside the main() function, replace the existing case statement with this:
case $template_number in
    1)
        shift 2
        create_nginx_template "$stack_name" "$@"
        ;;
    2)
        shift 2
        create_mysql_template "$stack_name" "$@"
        ;;
    3)
        shift 2
        create_postgres_template "$stack_name" "$@"
        ;;
    4)
        shift 2
        create_wordpress_template "$stack_name" "$@"
        ;;
    5)
        shift 2
        create_lamp_template "$stack_name" "$@"
        ;;
    6)
        shift 2
        create_monitoring_template "$stack_name" "$@"
        ;;
    7)
        shift 2
        create_traefik_template "$stack_name" "$@"
        ;;
    8)
        shift 2
        create_plex_template "$stack_name" "$@"
        ;;
    9)
        shift 2
        create_nodejs_template "$stack_name" "$@"
        ;;
    10)
        shift 2
        create_flask_template "$stack_name" "$@"
        ;;
    11)
        shift 2
        create_authentik_template "$stack_name" "$@"
        ;;
    *)
        echo "Invalid template number: $template_number"
        show_templates
        exit 1
        ;;
esac
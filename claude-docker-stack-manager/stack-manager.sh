#!/bin/bash

# Docker Stack Manager
# A tool for managing Docker Compose stacks with simplified commands
# Author: Claude

# Configuration
DOCKER_BASE_DIR="$HOME/docker"
STACKS_DIR="$DOCKER_BASE_DIR/stacks"
CONFIGS_DIR="$DOCKER_BASE_DIR/configs"
DATA_DIR="$DOCKER_BASE_DIR/data"
LOG_FILE="$DOCKER_BASE_DIR/docker-stack.log"

# Create directories if they don't exist
function init_dirs() {
    mkdir -p "$STACKS_DIR" "$CONFIGS_DIR" "$DATA_DIR"
    touch "$LOG_FILE"
    echo "Directory structure initialized at $DOCKER_BASE_DIR"
}

# Logging function
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> "$LOG_FILE"
    if [[ "$2" != "silent" ]]; then
        echo "$message"
    fi
}

# List all available stacks
function list_stacks() {
    echo "Available stacks:"
    if [ -d "$STACKS_DIR" ]; then
        local stacks=$(find "$STACKS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
        if [ -z "$stacks" ]; then
            echo "  No stacks found"
        else
            echo "$stacks" | sed 's/^/  /'

            # Show stack status if docker is available
            if command -v docker &> /dev/null; then
                echo -e "\nStack status:"
                for stack in $stacks; do
                    local container_count=$(docker compose -f "$STACKS_DIR/$stack/compose.yml" ps --quiet 2>/dev/null | wc -l)
                    if [ "$container_count" -gt 0 ]; then
                        echo "  $stack: running ($container_count containers)"
                    else
                        echo "  $stack: stopped"
                    fi
                done
            fi
        fi
    else
        echo "  Stack directory not found"
    fi
}

# Check if stack exists
function check_stack() {
    if [ -z "$1" ]; then
        echo "Error: No stack name provided"
        return 1
    fi

    if [ ! -d "$STACKS_DIR/$1" ]; then
        echo "Error: Stack '$1' not found"
        return 1
    fi

    if [ ! -f "$STACKS_DIR/$1/compose.yml" ]; then
        echo "Error: compose.yml not found for stack '$1'"
        return 1
    fi

    return 0
}

# Start a stack
function stack_up() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Starting stack: $1"
    log "Starting stack: $1"

    cd "$STACKS_DIR/$1"
    docker compose -f "$STACKS_DIR/$1/compose.yml" up -d

    if [ $? -eq 0 ]; then
        echo "Stack '$1' started successfully"
        log "Stack '$1' started successfully"
    else
        echo "Error starting stack '$1'"
        log "Error starting stack '$1'"
    fi
}

# Stop a stack
function stack_down() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Stopping stack: $1"
    log "Stopping stack: $1"

    cd "$STACKS_DIR/$1"
    docker compose -f "$STACKS_DIR/$1/compose.yml" down

    if [ $? -eq 0 ]; then
        echo "Stack '$1' stopped successfully"
        log "Stack '$1' stopped successfully"
    else
        echo "Error stopping stack '$1'"
        log "Error stopping stack '$1'"
    fi
}

# Restart a stack
function stack_restart() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Restarting stack: $1"
    log "Restarting stack: $1"

    stack_down "$1"
    stack_up "$1"
}

# View logs for a stack
function stack_logs() {
    if ! check_stack "$1"; then
        return 1
    fi

    local follow=""
    if [ "$2" == "-f" ] || [ "$2" == "--follow" ]; then
        follow="--follow"
    fi

    echo "Viewing logs for stack: $1"
    log "Viewing logs for stack: $1" silent

    cd "$STACKS_DIR/$1"
    docker compose -f "$STACKS_DIR/$1/compose.yml" logs $follow
}

# Create a new stack
function create_stack() {
    if [ -z "$1" ]; then
        echo "Error: No stack name provided"
        return 1
    fi

    # Check if stack already exists
    if [ -d "$STACKS_DIR/$1" ]; then
        echo "Error: Stack '$1' already exists"
        return 1
    fi

    echo "Creating new stack: $1"
    log "Creating new stack: $1"

    # Create directory structure
    mkdir -p "$STACKS_DIR/$1"
    mkdir -p "$CONFIGS_DIR/$1"
    mkdir -p "$DATA_DIR/$1"

    # Create empty compose.yml file with comments
    cat > "$STACKS_DIR/$1/compose.yml" << EOF
# Docker Compose configuration for '$1'
# Created $(date)

services:
  # Define your services here
  # example:
  #   image: namespace/image:tag
  #   container_name: ${1}_example
  #   restart: unless-stopped
  #   environment:
  #     - VARIABLE=value
  #   volumes:
  #     - $CONFIGS_DIR/$1/config:/config
  #     - $DATA_DIR/$1/data:/data
  #   ports:
  #     - "8080:80"

networks:
  default:
    name: ${1}_network
EOF

    echo "Stack '$1' created successfully"
    echo "Edit the compose file at: $STACKS_DIR/$1/compose.yml"
    log "Stack '$1' created successfully"
}

# Pull latest images for a stack
function stack_pull() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Pulling latest images for stack: $1"
    log "Pulling latest images for stack: $1"

    cd "$STACKS_DIR/$1"
    docker compose -f "$STACKS_DIR/$1/compose.yml" pull

    if [ $? -eq 0 ]; then
        echo "Images for stack '$1' pulled successfully"
        log "Images for stack '$1' pulled successfully"
    else
        echo "Error pulling images for stack '$1'"
        log "Error pulling images for stack '$1'"
    fi
}

# Update a stack (pull + restart)
function stack_update() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Updating stack: $1"
    log "Updating stack: $1"

    stack_pull "$1"
    stack_restart "$1"
}

# Check the status of a stack
function stack_status() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Status for stack: $1"
    log "Checking status for stack: $1" silent

    cd "$STACKS_DIR/$1"
    docker compose -f "$STACKS_DIR/$1/compose.yml" ps
}

# Edit a stack's compose file
function edit_stack() {
    if ! check_stack "$1"; then
        return 1
    fi

    local editor=${EDITOR:-vi}

    echo "Editing stack: $1"
    log "Editing stack: $1" silent

    $editor "$STACKS_DIR/$1/compose.yml"
}

# Validate a stack's compose file
function validate_stack() {
    if ! check_stack "$1"; then
        return 1
    fi

    echo "Validating stack: $1"
    log "Validating stack: $1"

    cd "$STACKS_DIR/$1"
    docker compose -f "$STACKS_DIR/$1/compose.yml" config

    if [ $? -eq 0 ]; then
        echo "Stack '$1' configuration is valid"
        log "Stack '$1' configuration is valid"
    else
        echo "Error: Stack '$1' configuration is invalid"
        log "Error: Stack '$1' configuration is invalid"
    fi
}

# Backup a stack's data
function backup_stack() {
    if ! check_stack "$1"; then
        return 1
    fi

    local backup_dir="$DOCKER_BASE_DIR/backups"
    local date_stamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/${1}_${date_stamp}.tar.gz"

    mkdir -p "$backup_dir"

    echo "Backing up stack: $1"
    log "Backing up stack: $1"

    # Create tar of the stack directory, config, and data
    tar -czf "$backup_file" \
        -C "$DOCKER_BASE_DIR" \
        "stacks/$1" \
        "configs/$1" \
        "data/$1"

    if [ $? -eq 0 ]; then
        echo "Stack '$1' backed up successfully to $backup_file"
        log "Stack '$1' backed up successfully to $backup_file"
    else
        echo "Error backing up stack '$1'"
        log "Error backing up stack '$1'"
        rm -f "$backup_file"
    fi
}

# Clone an existing stack to a new one
function clone_stack() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: Source and destination stack names required"
        echo "Usage: ds clone source_stack destination_stack"
        return 1
    fi

    if ! check_stack "$1"; then
        return 1
    fi

    if [ -d "$STACKS_DIR/$2" ]; then
        echo "Error: Destination stack '$2' already exists"
        return 1
    fi

    echo "Cloning stack '$1' to '$2'"
    log "Cloning stack '$1' to '$2'"

    # Create directory structure
    mkdir -p "$STACKS_DIR/$2"
    mkdir -p "$CONFIGS_DIR/$2"
    mkdir -p "$DATA_DIR/$2"

    # Copy compose file and modify it
    cp "$STACKS_DIR/$1/compose.yml" "$STACKS_DIR/$2/compose.yml"

    # Update paths and names in the compose file
    sed -i "s/$1/$2/g" "$STACKS_DIR/$2/compose.yml"

    # Copy .env file if it exists
    if [ -f "$STACKS_DIR/$1/.env" ]; then
        cp "$STACKS_DIR/$1/.env" "$STACKS_DIR/$2/.env"
    fi

    echo "Stack '$2' cloned from '$1' successfully"
    echo "You may want to review and edit: $STACKS_DIR/$2/compose.yml"
    log "Stack '$2' cloned from '$1' successfully"
}

# Prune unused Docker resources
function docker_prune() {
    echo "Pruning unused Docker resources"
    log "Pruning unused Docker resources"

    # Ask for confirmation
    read -p "This will remove all unused containers, networks, images and volumes. Continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker system prune -a --volumes
        echo "Docker resources pruned"
        log "Docker resources pruned"
    else
        echo "Operation cancelled"
        log "Docker prune operation cancelled"
    fi
}

# Show usage information
function show_help() {
    echo "Docker Stack Manager"
    echo "Usage: ds [command] [stack_name] [options]"
    echo
    echo "Commands:"
    echo "  init              Create the directory structure"
    echo "  list, ls          List all available stacks"
    echo "  create [name]     Create a new stack"
    echo "  up [name]         Start a stack"
    echo "  down [name]       Stop a stack"
    echo "  restart [name]    Restart a stack"
    echo "  logs [name] [-f]  View logs for a stack (use -f to follow)"
    echo "  pull [name]       Pull latest images for a stack"
    echo "  update [name]     Pull latest images and restart a stack"
    echo "  status [name]     Check the status of a stack"
    echo "  ps [name]         Alias for status"
    echo "  edit [name]       Edit a stack's compose file"
    echo "  validate [name]   Validate a stack's compose file"
    echo "  backup [name]     Backup a stack's data and configuration"
    echo "  clone [src] [dst] Clone an existing stack to a new one"
    echo "  prune             Prune unused Docker resources"
    echo "  help              Show this help message"
}

# Main function to parse arguments and execute commands
function main() {
    case "$1" in
        init)
            init_dirs
            ;;
        list|ls)
            list_stacks
            ;;
        create)
            create_stack "$2"
            ;;
        up)
            stack_up "$2"
            ;;
        down)
            stack_down "$2"
            ;;
        restart)
            stack_restart "$2"
            ;;
        logs)
            stack_logs "$2" "$3"
            ;;
        pull)
            stack_pull "$2"
            ;;
        update)
            stack_update "$2"
            ;;
        status|ps)
            stack_status "$2"
            ;;
        edit)
            edit_stack "$2"
            ;;
        validate)
            validate_stack "$2"
            ;;
        backup)
            backup_stack "$2"
            ;;
        clone)
            clone_stack "$2" "$3"
            ;;
        prune)
            docker_prune
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            if [ -z "$1" ]; then
                list_stacks
            else
                echo "Unknown command: $1"
                echo "Run 'ds help' for usage information"
            fi
            ;;
    esac
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in the PATH"
    exit 1
fi

# Run the main function with all arguments
main "$@"
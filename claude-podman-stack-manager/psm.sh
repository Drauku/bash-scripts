#!/usr/bin/env bash
#
# Podman Stack Manager (PSM)
# A script to manage Podman stacks with a standardized directory structure
# Author: Claude / ClaudeUser
# Date: 2025-04-18
# License: MIT

# -e: Exit immediately if a command exits with a non-zero status
# -u: Treat unset variables as an error
# -o pipefail: If any command in a pipeline fails, the pipeline's return code is the first non-zero return code
set -euo pipefail

# Configuration variables
PSM_VERSION="1.0.0"
BASE_DIR="${HOME}/docker"
COMMON_DIR="${BASE_DIR}/common"
LOCAL_DIR="${BASE_DIR}/local"
SWARM_DIR="${BASE_DIR}/swarm"
BACKUP_DIR="${BASE_DIR}/backup"
COLOR_CONFIG="${COMMON_DIR}/color_codes.conf"
VERBOSE=false
DEFAULT_MODE="local" # Default to local mode

# Source color codes if available
if [[ -f "${COLOR_CONFIG}" ]]; then
    source "${COLOR_CONFIG}"
else
    # Define color codes
    red="$(printf '\033[38;2;255;000;000m')"; export red
    orn="$(printf '\033[38;2;255;075;075m')"; export orn
    ylw="$(printf '\033[38;2;255;255;000m')"; export ylw
    grn="$(printf '\033[38;2;000;170;000m')"; export grn
    cyn="$(printf '\033[38;2;085;255;255m')"; export cyn
    blu="$(printf '\033[38;2;000;120;255m')"; export blu
    prp="$(printf '\033[38;2;085;085;255m')"; export prp
    mgn="$(printf '\033[38;2;255;085;255m')"; export mgn
    wht="$(printf '\033[38;2;255;255;255m')"; export wht
    blk="$(printf '\033[38;2;025;025;025m')"; export blk
    uln="$(printf '\033[4m')"; export uln
    bld="$(printf '\033[1m')"; export bld
    def="$(printf '\033[m')"; export def
fi

# Function: Display help message
function show_help() {
    echo -e "${bld}Podman Stack Manager (PSM) v${PSM_VERSION}${def}"
    echo
    echo -e "${bld}Usage:${def}"
    echo -e "  psm [options] <command> [stack_name]"
    echo
    echo -e "${bld}Commands:${def}"
    echo -e "  ${grn}install${def}                Install PSM and set up directory structure"
    echo -e "  ${grn}create${def} <stack_name>    Create a new stack directory structure (aliases: new|c)"
    echo -e "  ${grn}edit${def} <stack_name>      Edit the compose.yml for a stack (aliases: modify|m)"
    echo -e "  ${grn}up${def} <stack_name>        Start a stack (aliases: up|st)"
    echo -e "  ${grn}down${def} <stack_name>      Stop a stack (aliases: dn|sp)"
    echo -e "  ${grn}restart${def} <stack_name>   Restart a stack (aliases: rs)"
    echo -e "  ${grn}update${def} <stack_name>    Update containers in a stack (aliases: ud)"
    echo -e "  ${grn}remove${def} <stack_name>    Remove containers for a stack without deleting config (aliases: rm)"
    echo -e "  ${grn}delete${def} <stack_name>    Delete a stack and all its data (aliases: del)"
    echo -e "  ${grn}backup${def} <stack_name>    Backup a stack's data (aliases: bu)"
    echo -e "  ${grn}list${def}                   List all stacks (aliases: ls)"
    echo -e "  ${grn}status${def} <stack_name>    Show the status of containers in a stack (aliases: ps)"
    echo -e "  ${grn}logs${def} <stack_name>      Show logs for a stack"
    echo -e "  ${grn}validate${def} <stack_name>  Validate a stack's compose file"
    echo
    echo -e "${bld}Options:${def}"
    echo -e "  ${ylw}-m, --mode${def} <mode>     Specify mode: local or swarm (default: local)"
    echo -e "  ${ylw}-v, --verbose${def}         Enable verbose output"
    echo -e "  ${ylw}-h, --help${def}            Show this help message"
    echo
    echo -e "  ${grn}template list${def}          List available templates from GitHub/GitLab"
    echo -e "  ${grn}template fetch${def} <name>  Download a template stack"
    echo -e "${bld}Template Options:${def}"
    echo -e "  ${ylw}--provider${def} <provider> Specify template provider: github or gitlab (default: github)"
    echo -e "  ${ylw}--force${def}               Force overwrite when fetching template"
    echo
    echo -e "${bld}Examples:${def}"
    echo -e "  psm create nextcloud"
    echo -e "  psm up nextcloud"
    echo -e "  psm -m swarm up monitoring"
}

# Function: Log message with color
function log() {
    local level="$1"
    local message="$2"
    local color
    local prefix

    case "${level}" in
        info)
            color="${grn}"
            prefix="[INFO]"
            ;;
        warn)
            color="${ylw}"
            prefix="[WARN]"
            ;;
        error)
            color="${red}"
            prefix="[ERROR]"
            ;;
        debug)
            if [[ "${VERBOSE}" != "true" ]]; then
                return
            fi
            color="${blu}"
            prefix="[DEBUG]"
            ;;
        *)
            color="${wht}"
            prefix=""
            ;;
    esac

    echo -e "${color}${prefix}${def} ${message}"
}

# Function: Check if a stack exists
function stack_exists() {
    local stack_name="$1"
    local stack_dir

    if [[ "${DEFAULT_MODE}" == "local" ]]; then
        stack_dir="${LOCAL_DIR}/${stack_name}"
    else
        stack_dir="${SWARM_DIR}/${stack_name}"
    fi

    if [[ -d "${stack_dir}" ]]; then
        return 0
    else
        return 1
    fi
}

# Function: Get the compose file path for a stack
function get_compose_path() {
    local stack_name="$1"
    local stack_dir

    if [[ "${DEFAULT_MODE}" == "local" ]]; then
        stack_dir="${LOCAL_DIR}/${stack_name}"
    else
        stack_dir="${SWARM_DIR}/${stack_name}"
    fi

    echo "${stack_dir}/compose.yml"
}

# Function: Create a new stack directory structure
function create_stack() {
    local stack_name="$1"
    local stack_dir
    local env_source

    if [[ "${DEFAULT_MODE}" == "local" ]]; then
        stack_dir="${LOCAL_DIR}/${stack_name}"
        env_source="${COMMON_DIR}/secrets/.local.env"
    else
        stack_dir="${SWARM_DIR}/${stack_name}"
        env_source="${COMMON_DIR}/secrets/.swarm.env"
    fi

    if stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' already exists."
        return 1
    fi

    log "info" "Creating stack directory structure for '${stack_name}'..."

    # Create stack directory
    mkdir -p "${stack_dir}/appdata"

    # Create a symlink to the environment file
    if [[ -f "${env_source}" ]]; then
        ln -sf "${env_source}" "${stack_dir}/.env"
        log "debug" "Created symlink to environment file at ${stack_dir}/.env"
    else
        log "warn" "Environment file ${env_source} does not exist. Skipping .env symlink."
    fi

    # Create an example compose.yml file
    cat > "${stack_dir}/compose.yml" << EOF
# ${stack_name} stack - created by PSM on $(date +"%Y-%m-%d %H:%M:%S")
version: '3'

services:
  # Define your services here
  example:
    image: hello-world
    container_name: ${stack_name}-example
    restart: unless-stopped
    # Add your configuration here

volumes:
  # Define your volumes here

networks:
  # Define your networks here
EOF

    log "info" "Stack '${stack_name}' created successfully."
    log "info" "Edit the compose file with: psm edit ${stack_name}"
}

# Function: Edit a stack's compose file
function edit_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    # Use the default editor or fallback to vi
    if [[ -n "${EDITOR:-}" ]]; then
        ${EDITOR} "${compose_path}"
    else
        vi "${compose_path}"
    fi
}

# Function: Start a stack
function up_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Starting stack '${stack_name}'..."

    # Change to the stack directory to ensure relative paths work
    local current_dir
    current_dir=$(pwd)
    local stack_dir
    stack_dir=$(dirname "${compose_path}")
    cd "${stack_dir}"

    # Start the stack using podman compose
    podman compose -f "${compose_path}" up -d --remove-orphans

    # Return to the original directory
    cd "${current_dir}"

    log "info" "Stack '${stack_name}' started successfully."
}

# Function: Stop a stack
function down_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Stopping stack '${stack_name}'..."

    # Change to the stack directory to ensure relative paths work
    local current_dir
    current_dir=$(pwd)
    local stack_dir
    stack_dir=$(dirname "${compose_path}")
    cd "${stack_dir}"

    # Stop the stack using podman compose
    podman compose -f "${compose_path}" down

    # Return to the original directory
    cd "${current_dir}"

    log "info" "Stack '${stack_name}' stopped successfully."
}

# Function: Restart a stack
function restart_stack() {
    local stack_name="$1"

    log "info" "Restarting stack '${stack_name}'..."

    down_stack "${stack_name}" && up_stack "${stack_name}"

    log "info" "Stack '${stack_name}' restarted successfully."
}

# Function: Update containers in a stack
function update_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Updating stack '${stack_name}'..."

    # Change to the stack directory to ensure relative paths work
    local current_dir
    current_dir=$(pwd)
    local stack_dir
    stack_dir=$(dirname "${compose_path}")
    cd "${stack_dir}"

    # Pull latest images
    podman compose -f "${compose_path}" pull

    # Restart with new images
    podman compose -f "${compose_path}" up -d

    # Return to the original directory
    cd "${current_dir}"

    log "info" "Stack '${stack_name}' updated successfully."
}

# Function: Remove a stack (stop and remove containers, leaving config intact)
function remove_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Removing stack '${stack_name}'..."

    # Confirm removal
    read -p -r "$(echo -e "${ylw}Are you sure you want to remove stack '${stack_name}'? Containers will be stopped and removed. [y/N]: ${def}")" confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log "info" "Operation canceled."
        return 0
    fi

    # Change to the stack directory to ensure relative paths work
    local current_dir
    current_dir=$(pwd)
    local stack_dir
    stack_dir=$(dirname "${compose_path}")
    cd "${stack_dir}"

    # Remove containers using podman compose
    podman compose -f "${compose_path}" down

    # Return to the original directory
    cd "${current_dir}"

    log "info" "Stack '${stack_name}' removed successfully. Configuration files remain intact."
}

# Function: Delete a stack (remove containers and delete all configuration files)
function delete_stack() {
    local stack_name="$1"
    local stack_dir

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    if [[ "${DEFAULT_MODE}" == "local" ]]; then
        stack_dir="${LOCAL_DIR}/${stack_name}"
    else
        stack_dir="${SWARM_DIR}/${stack_name}"
    fi

    log "info" "Deleting stack '${stack_name}'..."

    # Confirm deletion
    read -p -r "$(echo -e "${red}WARNING: Are you sure you want to delete stack '${stack_name}'? This will remove all containers and DELETE ALL CONFIGURATION AND DATA for this stack. This action cannot be undone. [y/N]: ${def}")" confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log "info" "Operation canceled."
        return 0
    fi

    # Ask if the user wants to create a backup before deletion
    read -p -r "$(echo -e "${ylw}Would you like to create a backup before deleting? [Y/n]: ${def}")" backup_confirm
    if [[ "${backup_confirm}" != "n" && "${backup_confirm}" != "N" ]]; then
        backup_stack "${stack_name}"
    fi

    # Get the compose file path
    local compose_path
    compose_path=$(get_compose_path "${stack_name}")

    # Stop and remove containers if the compose file exists
    if [[ -f "${compose_path}" ]]; then
        # Change to the stack directory to ensure relative paths work
        local current_dir
        current_dir=$(pwd)
        cd "$(dirname "${compose_path}")"

        # Remove containers using podman compose
        log "debug" "Stopping and removing containers..."
        podman compose -f "${compose_path}" down -v

        # Return to the original directory
        cd "${current_dir}"
    fi

    # Delete the stack directory
    log "debug" "Removing stack directory and all contents..."
    rm -rf "${stack_dir}"

    log "info" "Stack '${stack_name}' deleted successfully."
}

# Enhanced Function: Backup a stack with space checking
function backup_stack() {
    local stack_name="$1"
    local stack_dir
    local backup_target_dir

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    if [[ "${DEFAULT_MODE}" == "local" ]]; then
        stack_dir="${LOCAL_DIR}/${stack_name}"
        backup_target_dir="${BACKUP_DIR}/local"
    else
        stack_dir="${SWARM_DIR}/${stack_name}"
        backup_target_dir="${BACKUP_DIR}/swarm"
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "${backup_target_dir}"

    # Generate backup filename with timestamp
    local timestamp
    timestamp=$(date +"%Y_%m_%d_%H%M")
    local backup_file="${backup_target_dir}/${stack_name}-${timestamp}.tar.gz"

    # Check stack directory size
    local stack_size
    stack_size=$(du -sb "${stack_dir}/appdata" 2>/dev/null | awk '{print $1}' || echo "0")

    # If stack size calculation failed, estimate 1GB
    if [[ "${stack_size}" == "0" ]]; then
        log "warn" "Could not determine stack size. Assuming 1GB."
        stack_size=$((1024*1024*1024))
    fi

    # Add 20% buffer for compression overhead and safety margin
    local required_space=$((stack_size * 120 / 100))

    # Check free space in backup directory
    local backup_df
    backup_df=$(df -B1 "${backup_target_dir}" | tail -1)
    local available_space
    available_space=$(echo "${backup_df}" | awk '{print $4}')

    log "debug" "Required space: $(numfmt --to=iec-i --suffix=B "${required_space}")"
    log "debug" "Available space: $(numfmt --to=iec-i --suffix=B "${available_space}")"

    # Verify sufficient free space
    if [[ ${available_space} -lt ${required_space} ]]; then
        log "error" "Insufficient disk space for backup."
        log "error" "Required: $(numfmt --to=iec-i --suffix=B ${required_space}), Available: $(numfmt --to=iec-i --suffix=B "${available_space}")"
        return 1
    fi

    log "info" "Backing up stack '${stack_name}' to ${backup_file}..."

    # Create the backup archive
    if tar -czf "${backup_file}" -C "${stack_dir}" appdata; then
        log "info" "Stack '${stack_name}' backed up successfully."
        log "info" "Backup size: $(du -h "${backup_file}" | awk '{print $1}')"
    else
        log "error" "Backup failed."
        # Remove partial backup file if it exists
        if [[ -f "${backup_file}" ]]; then
            rm -f "${backup_file}"
        fi
        return 1
    fi
}

# Function: List all stacks
function list_stacks() {
    local mode_dir

    if [[ "${DEFAULT_MODE}" == "local" ]]; then
        mode_dir="${LOCAL_DIR}"
        log "info" "Listing local stacks:"
    else
        mode_dir="${SWARM_DIR}"
        log "info" "Listing swarm stacks:"
    fi

    if [[ ! -d "${mode_dir}" ]]; then
        log "error" "Directory ${mode_dir} does not exist."
        return 1
    fi

    local stacks
    # stacks=($(find "${mode_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
    mapfile -t stacks < <(find "${mode_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
    # read -r -a stacks < <(find "${mode_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;) # for bash < 4

    if [[ ${#stacks[@]} -eq 0 ]]; then
        log "info" "No stacks found."
        return 0
    fi

    echo -e "${bld}Available stacks:${def}"
    for stack in "${stacks[@]}"; do
        local compose_file="${mode_dir}/${stack}/compose.yml"
        if [[ -f "${compose_file}" ]]; then
            echo -e "  - ${grn}${stack}${def}"
        else
            echo -e "  - ${ylw}${stack}${def} (no compose file)"
        fi
    done
}

# Function: Show the status of containers in a stack
function status_stack() {
    local stack_name="$1"
    local compose_path

    if [[ -z "${stack_name}" ]]; then
        # If no stack name is provided, show all containers
        log "info" "Showing status of all containers:"
        podman ps
        return 0
    fi

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Showing status for stack '${stack_name}':"

    # Change to the stack directory to ensure relative paths work
    local current_dir
    current_dir=$(pwd)
    local stack_dir
    stack_dir=$(dirname "${compose_path}")
    cd "${stack_dir}"

    # Show stack status
    podman compose -f "${compose_path}" ps

    # Return to the original directory
    cd "${current_dir}"
}

# Function: Show logs for a stack
function logs_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Showing logs for stack '${stack_name}':"

    # Change to the stack directory to ensure relative paths work
    local current_dir
    current_dir=$(pwd)
    local stack_dir
    stack_dir=$(dirname "${compose_path}")
    cd "${stack_dir}"

    # Show stack logs
    podman compose -f "${compose_path}" logs

    # Return to the original directory
    cd "${current_dir}"
}

# Function: Validate a stack's compose file
function validate_stack() {
    local stack_name="$1"
    local compose_path

    if ! stack_exists "${stack_name}"; then
        log "error" "Stack '${stack_name}' does not exist."
        return 1
    fi

    compose_path=$(get_compose_path "${stack_name}")

    if [[ ! -f "${compose_path}" ]]; then
        log "error" "Compose file for stack '${stack_name}' does not exist."
        return 1
    fi

    log "info" "Validating compose file for stack '${stack_name}'..."

    # Validate the compose file
    if podman compose -f "${compose_path}" config --quiet; then
        log "info" "Compose file for stack '${stack_name}' is valid."
        return 0
    else
        log "error" "Compose file for stack '${stack_name}' is invalid."
        return 1
    fi
}

# Function: List available templates from GitHub/GitLab repositories
function list_templates() {
    local provider="${1:-github}"  # Default to GitHub if not specified
    local mode="${DEFAULT_MODE}"   # Use the current mode (local or swarm)
    local temp_dir
    local repo_url
    local raw_content_url
    local api_url

    # Set repository URLs based on provider
    case "${provider}" in
        github)
            repo_url="https://github.com/podman-stack-manager/stacks"
            raw_content_url="https://raw.githubusercontent.com/podman-stack-manager/stacks/main"
            api_url="https://api.github.com/repos/podman-stack-manager/stacks/contents/${mode}"
            ;;
        gitlab)
            repo_url="https://gitlab.com/podman-stack-manager/stacks"
            raw_content_url="https://gitlab.com/podman-stack-manager/stacks/-/raw/main"
            api_url="https://gitlab.com/api/v4/projects/podman-stack-manager%2Fstacks/repository/tree?path=${mode}"
            ;;
        *)
            log "error" "Invalid provider: ${provider}. Must be 'github' or 'gitlab'."
            return 1
            ;;
    esac

    log "info" "Fetching available ${mode} templates from ${provider}..."

    # Check if required tools are available
    if ! command -v curl >/dev/null; then
        log "error" "curl is required but not installed. Please install curl and try again."
        return 1
    fi

    if ! command -v jq >/dev/null; then
        log "error" "jq is required but not installed. Please install jq and try again."
        return 1
    fi

    # Create a temporary directory for working files
    temp_dir=$(mktemp -d)
    trap 'rm -rf ${temp_dir}' EXIT

    # Fetch repository contents using API
    local response_file="${temp_dir}/response.json"

    if [[ "${provider}" == "github" ]]; then
        # GitHub API
        curl -s -H "Accept: application/vnd.github.v3+json" "${api_url}" > "${response_file}"

        # Check if API rate limit exceeded or other error
        if grep -q "API rate limit exceeded" "${response_file}"; then
            log "error" "GitHub API rate limit exceeded. Try again later or authenticate."
            return 1
        fi

        # Check if directory exists
        if grep -q "Not Found" "${response_file}"; then
            log "error" "Directory '${mode}' not found in repository."
            return 1
        fi

        # Extract directories (potential stack templates)
        jq -r '.[] | select(.type == "dir") | .name' "${response_file}" > "${temp_dir}/templates.txt"
    else
        # GitLab API
        curl -s "${api_url}" > "${response_file}"

        # Check if directory exists
        if grep -q "404 Project Not Found" "${response_file}"; then
            log "error" "Repository or directory not found."
            return 1
        fi

        # Extract directories (potential stack templates)
        jq -r '.[] | select(.type == "tree") | .name' "${response_file}" > "${temp_dir}/templates.txt"
    fi

    # Check if any templates were found
    if [[ ! -s "${temp_dir}/templates.txt" ]]; then
        log "warn" "No templates found in ${provider} repository."
        return 0
    fi

    # Display available templates
    echo -e "${BOLD}Available ${mode} templates:${def}"
    sort "${temp_dir}/templates.txt" | nl -w2 -s") "

    return 0
}

# Function: Fetch a template from GitHub/GitLab repository
function fetch_template() {
    local stack_name="$1"
    local provider="${2:-github}"  # Default to GitHub if not specified
    local mode="${DEFAULT_MODE}"   # Use the current mode (local or swarm)
    local force="${3:-false}"      # Whether to overwrite existing stack
    local stack_dir
    local repo_url
    local raw_content_url
    local temp_dir

    # Set repository URLs based on provider
    case "${provider}" in
        github)
            repo_url="https://github.com/podman-stack-manager/stacks"
            raw_content_url="https://raw.githubusercontent.com/podman-stack-manager/stacks/main"
            ;;
        gitlab)
            repo_url="https://gitlab.com/podman-stack-manager/stacks"
            raw_content_url="https://gitlab.com/podman-stack-manager/stacks/-/raw/main"
            ;;
        *)
            log "error" "Invalid provider: ${provider}. Must be 'github' or 'gitlab'."
            return 1
            ;;
    esac

    # Determine stack directory based on mode
    if [[ "${mode}" == "local" ]]; then
        stack_dir="${LOCAL_DIR}/${stack_name}"
    else
        stack_dir="${SWARM_DIR}/${stack_name}"
    fi

    # Check if stack already exists
    if [[ -d "${stack_dir}" && "${force}" != "true" ]]; then
        log "error" "Stack '${stack_name}' already exists. Use --force to overwrite."
        return 1
    fi

    log "info" "Fetching template '${stack_name}' from ${provider}..."

    # Check if required tools are available
    if ! command -v curl >/dev/null; then
        log "error" "curl is required but not installed. Please install curl and try again."
        return 1
    fi

    # Create a temporary directory for working files
    temp_dir=$(mktemp -d)
    trap 'rm -rf ${temp_dir}' EXIT

    # Fetch the compose.yml file
    local template_url="${raw_content_url}/${mode}/${stack_name}/compose.yml"
    local compose_file="${temp_dir}/compose.yml"

    log "debug" "Downloading from ${template_url}..."

    # Download compose file
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "${compose_file}" "${template_url}")

    # Check if download was successful
    if [[ "${http_code}" != "200" ]]; then
        log "error" "Failed to download template. HTTP status: ${http_code}"
        log "error" "Template '${stack_name}' might not exist in the repository."
        return 1
    fi

    # Create stack directory structure if it doesn't exist
    if [[ ! -d "${stack_dir}" ]]; then
        mkdir -p "${stack_dir}/appdata"
        log "debug" "Created directory structure for '${stack_name}'."
    fi

    # Check for .env file template
    local env_template_url="${raw_content_url}/${mode}/${stack_name}/.env.example"
    local env_file="${temp_dir}/.env.example"

    # Try to download .env.example file (don't fail if it doesn't exist)
    curl -s -o "${env_file}" "${env_template_url}"

    # Create symlink to environment file if it doesn't exist
    if [[ ! -L "${stack_dir}/.env" ]]; then
        if [[ "${mode}" == "local" ]]; then
            ln -sf "${COMMON_DIR}/secrets/.local.env" "${stack_dir}/.env"
        else
            ln -sf "${COMMON_DIR}/secrets/.swarm.env" "${stack_dir}/.env"
        fi
        log "debug" "Created symlink to environment file."
    fi

    # Copy the compose file to the stack directory
    cp "${compose_file}" "${stack_dir}/compose.yml"

    # If .env.example exists and has content, create an example file
    if [[ -s "${env_file}" ]]; then
        cp "${env_file}" "${stack_dir}/.env.example"

        # Check if there are any environment variables to add to .env
        log "info" "Example environment variables found. Checking against current .env file..."

        # Get the target .env file
        local target_env_file
        if [[ "${mode}" == "local" ]]; then
            target_env_file="${COMMON_DIR}/secrets/.local.env"
        else
            target_env_file="${COMMON_DIR}/secrets/.swarm.env"
        fi

        # Create .env file if it doesn't exist
        if [[ ! -f "${target_env_file}" ]]; then
            touch "${target_env_file}"
        fi

        # Add any missing environment variables to the .env file
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            if [[ "${line}" =~ ^[[:space:]]*# || -z "${line}" ]]; then
                continue
            fi

            # Extract variable name (before =)
            local var_name="${line%%=*}"

            # Check if the variable exists in the .env file
            if ! grep -q "^${var_name}=" "${target_env_file}" 2>/dev/null; then
                log "info" "Adding environment variable '${var_name}' to .env file."
                echo "${line}" >> "${target_env_file}"
            fi
        done < "${env_file}"
    fi

    # Check for README file
    local readme_url="${raw_content_url}/${mode}/${stack_name}/README.md"
    local readme_file="${temp_dir}/README.md"

    # Try to download README file (don't fail if it doesn't exist)
    curl -s -o "${readme_file}" "${readme_url}"

    # If README exists and has content, copy it to the stack directory
    if [[ -s "${readme_file}" ]]; then
        cp "${readme_file}" "${stack_dir}/README.md"
        log "debug" "Copied README file."
    fi

    # Check for additional files with a manifest.json
    local manifest_url="${raw_content_url}/${mode}/${stack_name}/manifest.json"
    local manifest_file="${temp_dir}/manifest.json"

    # Try to download manifest file (don't fail if it doesn't exist)
    curl -s -o "${manifest_file}" "${manifest_url}"

    # If manifest exists and has content, process it
    if [[ -s "${manifest_file}" ]]; then
        log "debug" "Processing manifest file for additional resources..."

        # Check if jq is available
        if command -v jq >/dev/null; then
            # Extract additional files from manifest
            local files
            files=$(jq -r '.files[]?' "${manifest_file}" 2>/dev/null || echo "")

            if [[ -n "${files}" ]]; then
                for file in ${files}; do
                    local file_url="${raw_content_url}/${mode}/${stack_name}/${file}"
                    local file_path="${temp_dir}/${file}"
                    local dir_path
                    dir_path=$(dirname "${file_path}")

                    # Create directory structure if needed
                    mkdir -p "${dir_path}"

                    # Download the file
                    curl -s -o "${file_path}" "${file_url}"

                    # Copy file to stack directory
                    if [[ -s "${file_path}" ]]; then
                        mkdir -p "${stack_dir}/$(dirname "${file}")"
                        cp "${file_path}" "${stack_dir}/${file}"
                        log "debug" "Copied additional file: ${file}"
                    fi
                done
            fi
        else
            log "warn" "jq not installed. Skipping processing of additional files from manifest."
        fi
    fi

    log "info" "Template '${stack_name}' has been successfully imported."
    log "info" "You can now start the stack with: psm up ${stack_name}"

    # If README exists, offer to display it
    if [[ -f "${stack_dir}/README.md" ]]; then
        read -p -r "$(echo -e "${ylw}Would you like to view the README file? [y/N]: ${def}")" view_readme
        if [[ "${view_readme}" == "y" || "${view_readme}" == "Y" ]]; then
            # Check for various markdown viewers
            if command -v glow >/dev/null; then
                glow "${stack_dir}/README.md"
            elif command -v mdcat >/dev/null; then
                mdcat "${stack_dir}/README.md"
            elif command -v less >/dev/null; then
                less "${stack_dir}/README.md"
            else
                cat "${stack_dir}/README.md"
            fi
        fi
    fi

    return 0
}

# Function: Manage templates (list and fetch)
function manage_templates() {
    local action="$1"
    local provider="${2:-github}"  # Default to GitHub if not specified
    local stack_name="$3"
    local force="$4"

    case "${action}" in
        list)
            list_templates "${provider}"
            ;;
        fetch)
            if [[ -z "${stack_name}" ]]; then
                # List templates first, then ask user to select one
                if list_templates "${provider}"; then
                    read -p -r "$(echo -e "${ylw}Enter template number or name to fetch: ${def}")" selection

                    # Check if selection is a number
                    if [[ "${selection}" =~ ^[0-9]+$ ]]; then
                        # Get template name from temp file
                        stack_name=$(sed -n "${selection}p" "${temp_dir}/templates.txt" 2>/dev/null)
                        if [[ -z "${stack_name}" ]]; then
                            log "error" "Invalid selection."
                            return 1
                        fi
                    else
                        # Use selection as template name
                        stack_name="${selection}"
                    fi
                else
                    return 1
                fi
            fi

            fetch_template "${stack_name}" "${provider}" "${force}"
            ;;
        *)
            log "error" "Invalid action: ${action}. Must be 'list' or 'fetch'."
            return 1
            ;;
    esac

    return 0
}

# Parse command line arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case "${key}" in
        -m|--mode)
            if [[ "$2" == "local" || "$2" == "swarm" ]]; then
                DEFAULT_MODE="$2"
                shift 2
            else
                log "error" "Invalid mode: $2. Must be 'local' or 'swarm'."
                exit 1
            fi
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${POSITIONAL[@]}"

# Check if a command is provided
if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

# Process commands
command="$1"
shift

case "${command}" in
    create|new|n)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for create command."
            exit 1
        fi
        create_stack "$1"
        ;;
    edit|modify|m)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for edit command."
            exit 1
        fi
        edit_stack "$1"
        ;;
    up|start|st)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for up command."
            exit 1
        fi
        up_stack "$1"
        ;;
    dn|down|stop|sp)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for down command."
            exit 1
        fi
        down_stack "$1"
        ;;
    restart|rs)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for restart command."
            exit 1
        fi
        restart_stack "$1"
        ;;
    update|ud)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for update command."
            exit 1
        fi
        update_stack "$1"
        ;;
    remove|rm|r)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for remove command."
            exit 1
        fi
        remove_stack "$1"
        ;;
    delete|del|d)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for delete command."
            exit 1
        fi
        delete_stack "$1"
        ;;
    backup|bu)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for backup command."
            exit 1
        fi
        backup_stack "$1"
        ;;
    list|ls)
        list_stacks
        ;;
    status|ps)
        status_stack "${1:-}"
        ;;
    logs)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for logs command."
            exit 1
        fi
        logs_stack "$1"
        ;;
    validate|v)
        if [[ $# -ne 1 ]]; then
            log "error" "Missing stack name for validate command."
            exit 1
        fi
        validate_stack "$1"
        ;;
    template|t)
        if [[ $# -lt 1 ]]; then
            log "error" "Missing action for template command. Use 'list' or 'fetch'."
            exit 1
        fi

        # Parse template command options
        template_action="$1"
        shift

        template_provider="github"
        template_name=""
        template_force="false"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --provider|-p)
                    if [[ "$2" == "github" || "$2" == "gitlab" ]]; then
                        template_provider="$2"
                        shift 2
                    else
                        log "error" "Invalid provider: $2. Must be 'github' or 'gitlab'."
                        exit 1
                    fi
                    ;;
                --force|-f)
                    template_force="true"
                    shift
                    ;;
                *)
                    template_name="$1"
                    shift
                    ;;
            esac
        done

        manage_templates "${template_action}" "${template_provider}" "${template_name}" "${template_force}"
        ;;
    *)
        log "error" "Unknown command: ${command}"
        show_help
        exit 1
        ;;
esac

exit 0
#!/usr/bin/env bash
#
# Podman Stack Manager (PSM) Installation Script
# Sets up directory structure and configures aliases
# Author: Claude / ClaudeUser
# Date: 2025-04-18
# License: MIT

set -euo pipefail

# Configuration variables
PSM_VERSION="1.0.0"
BASE_DIR="${HOME}/docker"
COMMON_DIR="${BASE_DIR}/common"
LOCAL_DIR="${BASE_DIR}/local"
SWARM_DIR="${BASE_DIR}/swarm"
BACKUP_DIR="${BASE_DIR}/backup"
SECRETS_DIR="${COMMON_DIR}/secrets"
SCRIPT_PATH="${COMMON_DIR}/psm.sh"
RC_FILE="${HOME}/.bashrc"

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
    # echo " $red red $orn orn $ylw ylw $grn grn $cyn cyn $blu blu $prp prp $mgn mgn $wht wht $blk blk $def def"

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
            color="${blu}"
            prefix="[DEBUG]"
            ;;
        *)
            color=""
            prefix=""
            ;;
    esac

    echo -e "${color}${prefix}${def} ${message}"
}

# Function: Create directory structure
function create_directory_structure() {
    log "info" "Creating directory structure..."

    # Create main directories
    mkdir -p "${COMMON_DIR}"
    mkdir -p "${LOCAL_DIR}"
    mkdir -p "${SWARM_DIR}"
    mkdir -p "${BACKUP_DIR}/local"
    mkdir -p "${BACKUP_DIR}/swarm"
    mkdir -p "${SECRETS_DIR}"

    log "info" "Directory structure created successfully."
}

# Function: Create color configuration file
function create_color_config() {
    log "info" "Creating color configuration file..."

    cat > "${COMMON_DIR}/color_codes.conf" << EOF
# Color codes for PSM
red='\033[0;31m'
grn='\033[0;32m'
ylw='\033[0;33m'
blu='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color
EOF

    log "info" "Color configuration file created successfully."
}

# Function: Create example .env files
function create_env_files() {
    log "info" "Creating example .env files..."

    cat > "${COMMON_DIR}/dk_example.env" << EOF
# Example environment file for PSM
# Copy this file to ${SECRETS_DIR}/.local.env or ${SECRETS_DIR}/.swarm.env
# and modify as needed

# Common variables
PUID=1000
PGID=1000
TZ=UTC

# Network configuration
DOMAIN=example.com
EOF

    # Create template environment files
    if [[ ! -f "${SECRETS_DIR}/.local.env" ]]; then
        cp "${COMMON_DIR}/dk_example.env" "${SECRETS_DIR}/.local.env"
    else
        log "warn" "File ${SECRETS_DIR}/.local.env already exists. Skipping."
    fi

    if [[ ! -f "${SECRETS_DIR}/.swarm.env" ]]; then
        cp "${COMMON_DIR}/dk_example.env" "${SECRETS_DIR}/.swarm.env"
    else
        log "warn" "File ${SECRETS_DIR}/.swarm.env already exists. Skipping."
    fi

    if [[ ! -f "${SECRETS_DIR}/.vars.env" ]]; then
        cat > "${SECRETS_DIR}/.vars.env" << EOF
# Global variables for PSM
# These variables will be available to all scripts

# Base directory for PSM
PSM_BASE_DIR="${BASE_DIR}"
EOF
    else
        log "warn" "File ${SECRETS_DIR}/.vars.env already exists. Skipping."
    fi

    log "info" "Example .env files created successfully."
}

# Function: Install PSM script
function install_psm_script() {
    log "info" "Installing PSM script..."

    # Check if script exists and is executable
    if [[ ! -f "$0" ]]; then
        log "error" "Could not find PSM script."
        return 1
    fi

    # Copy the main script to the common directory
    cp "${0%/*}/psm.sh" "${SCRIPT_PATH}"
    chmod +x "${SCRIPT_PATH}"

    log "info" "PSM script installed successfully."
}

# Function: Configure aliases
function configure_aliases() {
    log "info" "Configuring aliases..."

    # Check if aliases already exist
    if grep -q "# PSM aliases" "${RC_FILE}" 2>/dev/null; then
        log "warn" "PSM aliases already exist in ${RC_FILE}. Skipping."
        return 0
    fi

    # Add aliases to bashrc
    cat >> "${RC_FILE}" << EOF

# PSM aliases
alias psm='${SCRIPT_PATH}'
EOF

    log "info" "Aliases configured successfully."
    log "info" "Run 'source ${RC_FILE}' to load the aliases in the current session."
}

# Main function
function main() {
    log "info" "Installing Podman Stack Manager (PSM) v${PSM_VERSION}..."

    create_directory_structure
    create_color_config
    create_env_files
    install_psm_script
    configure_aliases

    log "info" "PSM installation completed successfully."
    log "info" "Use 'psm --help' to see available commands."
}

# Run the main function
main
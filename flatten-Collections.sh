#!/bin/bash
# =============================================================================
# Collection Directory Reorganizer
# =============================================================================
#
# Description:
#   This script reorganizes directory structures by finding directories ending
#   with "Collection" and moving their subdirectories up to a specified target
#   directory. This effectively flattens nested directory structures.
#
# Author: Drauku
# Version: 1.0.0
# License: MIT
#
# Usage:
#   ./flatten_Collections.sh [-d] [-f] [-v] [-h] source_directory [target_directory]
#
# Examples:
#   # Move subdirectories to the same parent directory
#   ./flatten_Collections.sh /path/to/media/library
#
#   # Move subdirectories to a different target directory
#   ./flatten_Collections.sh /path/to/source /path/to/destination
#
#   # Preview what would be moved without making changes
#   ./flatten_Collections.sh -d /path/to/media/library
#
#   # Run with verbose output and skip all confirmations
#   ./flatten_Collections.sh -v -f /path/to/media/library
#
# Options:
#   -d, --dry-run    Show what would be moved without performing actual operations
#   -f, --force      Skip all confirmations and force operations
#   -v, --verbose    Enable verbose output
#   -h, --help       Display help message and exit
#
# Compatibility:
#   - Linux (all major distributions)
#   - macOS
#   - FreeBSD (including TrueNAS Scale)
#   - Unraid OS
#
# Requirements:
#   - Bash 4.0+
#   - find, cp, rm core utilities
#
# =============================================================================

# Exit on error, undefined variable, and error in piped commands
set -euo pipefail

# Version
readonly VERSION="1.0.0"


# -----------------------------------------------------------------------------
# Global Variables
# -----------------------------------------------------------------------------

VERBOSE=false
ORIGINAL_DIR=$(pwd)
REPOSITORY="https://github.com/drauku/bash-scripts"
DOWNLOAD="https://raw.githubusercontent.com/drauku/bash-scripts/master/flatten-Collections.sh"

# Color code variables
red=$'\033[38;2;255;000;000m'; export red
orn=$'\033[38;2;255;075;075m'; export orn
ylw=$'\033[38;2;255;255;000m'; export ylw
grn=$'\033[38;2;000;170;000m'; export grn
cyn=$'\033[38;2;085;255;255m'; export cyn
blu=$'\033[38;2;000;120;255m'; export blu
prp=$'\033[38;2;085;085;255m'; export prp
mgn=$'\033[38;2;255;085;255m'; export mgn
wht=$'\033[38;2;255;255;255m'; export wht
blk=$'\033[38;2;025;025;025m'; export blk
def=$'\033[m'; export def

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Display usage information
usage() {
    echo "Collection Directory Reorganizer v${VERSION}"
    echo ""
    echo "Usage: $0 [-d] [-f] [-v] [-h] source_directory [target_directory]"
    echo "This script will find all subdirectories ending with 'Collection'"
    echo "and move all their subdirectories to either the source directory"
    echo "or the specified target directory."
    echo ""
    echo "Options:"
    echo "  -d, --dry-run    Show what would be moved without performing actual operations"
    echo "  -f, --force      Skip all confirmations and force operations"
    echo "  -v, --verbose    Enable verbose output"
    echo "  -h, --help       Display this help message and exit"
    echo ""
    echo "For more information, see: ${REPOSITORY}"
    echo "To download the script, run this bash command:"
    echo "  curl -sSL ${DOWNLOAD} > flatten-Collections.sh"
    exit 1
}

# Log messages with appropriate level formatting
log() {
    local level="$1"
    local message="$2"

    case "$level" in
        "INFO")
            if [ "$VERBOSE" = true ]; then
                echo "[${cyn:?}INFO${def:?}] $message"
            fi
            ;;
        "WARNING")
            echo "[${ylw:?}WARNING${def:?}] $message" >&2
            ;;
        "ERROR")
            echo "[${red:?}ERROR${def:?}] $message" >&2
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Perform cleanup on exit
cleanup() {
    # Return to original directory
    cd "$ORIGINAL_DIR" 2>/dev/null || true
    log "INFO" "Script exited ${1:-normally}"
}

# Check if a required command exists
check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log "ERROR" "Required command '$1' not found. Please install it.";
        return 1;
    }
    return 0
}

# Safely get absolute path (handling symlinks)
get_absolute_path() {
    local path="$1"
    # First check if the path exists
    if [ ! -d "$path" ] && [ ! -L "$path" ]; then
        log "ERROR" "Path does not exist: $path"
        return 1
    fi

    # Handle symlinks and get absolute path
    local abs_path
    if command -v readlink >/dev/null 2>&1 && readlink -f "$path" >/dev/null 2>&1; then
        # Linux-style readlink with -f
        abs_path=$(readlink -f "$path")
    else
        # Fallback for systems without readlink -f (like macOS)
        abs_path=$(cd -P "$(dirname "$path")" && pwd)/$(basename "$path")
    fi

    echo "$abs_path"
    return 0
}

# Check available disk space and prompt if needed
check_disk_space() {
    local source_dir="$1"
    local target_dir="$2"
    local dry_run="$3"
    local force="$4"

    # Always check disk space for information purposes
    local source_size
    local target_avail

    log "INFO" "Checking available disk space..."

    # Handle potential errors from du/df commands gracefully
    if ! source_size=$(du -s "$source_dir" 2>/dev/null | awk '{print $1}'); then
        log "WARNING" "Could not determine source directory size - skipping space check"
        return 0
    fi

    # Try different df options for cross-platform compatibility
    if ! target_avail=$(df --no-sync -k "$target_dir" 2>/dev/null | awk 'NR==2 {print $4}'); then
        if ! target_avail=$(df -k "$target_dir" 2>/dev/null | awk 'NR==2 {print $4}'); then
            log "WARNING" "Could not determine available space - skipping space check"
            return 0
        fi
    fi

    if [ "$target_avail" -lt "$source_size" ]; then
        log "WARNING" "Target directory may not have enough available space"
        log "WARNING" "Source size: $(($source_size / 1024)) MB, Target available: $(($target_avail / 1024)) MB"

        # Only prompt if we're going to actually perform operations (not dry run)
        # and user hasn't explicitly forced operations
        if [ "$dry_run" = false ] && [ "$force" = false ]; then
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "NORMAL" "Operation cancelled by user"
                return 1
            fi
        elif [ "$dry_run" = false ] && [ "$force" = true ]; then
            log "WARNING" "Continuing despite space concerns (force mode enabled)"
        fi
        # If it's a dry run, just show the warning but don't prompt
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

# Process collection directories
process_collections() {
    local source_dir="$1"
    local target_dir="$2"
    local dry_run="$3"
    local dirs_moved=0
    local dirs_skipped=0
    local errors=0
    local collections_found=false

    log "INFO" "Searching for Collection directories..."

    # Use find with appropriate options (-L to follow symbolic links)
    # Get only immediate subdirectories ending with "Collection"
    local collections
    collections=$(find -L . -maxdepth 1 -type d -name "*Collection" | sort)

    # Check if any collections were found
    if [ -z "$collections" ]; then
        log "WARNING" "No directories ending with 'Collection' found in $source_dir"
        return 0
    fi

    # Process each collection
    echo "$collections" | while IFS= read -r collection_dir; do
        collections_found=true
        log "NORMAL" "Processing: $collection_dir"

        # Check if collection directory is readable
        if [ ! -r "$collection_dir" ]; then
            log "ERROR" "Cannot read collection directory '$collection_dir' (permission denied)"
            errors=$((errors + 1))
            continue
        fi

        # Find all immediate subdirectories within the collection directory
        local subdirs
        subdirs=$(find -L "$collection_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

        # Check if any subdirectories were found
        if [ -z "$subdirs" ]; then
            log "INFO" "No subdirectories found in $collection_dir"
            continue
        fi

        echo "$subdirs" | while IFS= read -r subdir; do
            local subdir_name
            subdir_name=$(basename "$subdir")

            # Check if a directory with the same name already exists in the target directory
            if [ -d "$target_dir/$subdir_name" ] || [ -L "$target_dir/$subdir_name" ]; then
                log "WARNING" "Directory or symlink '$subdir_name' already exists in the target directory. Skipping."
                dirs_skipped=$((dirs_skipped + 1))
                continue
            fi

            # Check if source directory is readable and has content
            if [ ! -r "$subdir" ]; then
                log "ERROR" "Cannot read source '$subdir' (permission denied)"
                errors=$((errors + 1))
                continue
            fi

            # Display the move operation
            log "NORMAL" "MOVE: '$subdir' → '$target_dir/$subdir_name'"

            # Perform the move if not in dry run mode
            if [ "$dry_run" = false ]; then
                # Use cp followed by rm for cross-filesystem compatibility
                if cp -a "$subdir" "$target_dir/" 2>/dev/null; then
                    if rm -rf "$subdir" 2>/dev/null; then
                        log "NORMAL" "Successfully moved: $subdir_name"
                        dirs_moved=$((dirs_moved + 1))
                    else
                        log "WARNING" "Copied '$subdir_name' to target but failed to remove source"
                        dirs_moved=$((dirs_moved + 1))
                    fi
                else
                    log "ERROR" "Failed to copy: $subdir_name"
                    errors=$((errors + 1))
                fi
            else
                dirs_moved=$((dirs_moved + 1))
            fi
        done

        log "NORMAL" "Completed processing: $collection_dir"
        echo "------------------------------------------"
    done

    # Show summary
    if [ "$dry_run" = true ]; then
        echo "============================================"
        log "NORMAL" "DRY RUN COMPLETE: No files were moved"
        log "NORMAL" "Would move: $dirs_moved directories"
        log "NORMAL" "Would skip: $dirs_skipped directories"
        if [ $errors -gt 0 ]; then
            log "WARNING" "Potential errors: $errors"
        fi
    else
        log "NORMAL" "Script execution completed"
        log "NORMAL" "Directories moved: $dirs_moved"
        log "NORMAL" "Directories skipped: $dirs_skipped"
        if [ $errors -gt 0 ]; then
            log "ERROR" "Errors encountered: $errors"
            return 1
        fi
    fi

    # Verify at least one collection directory was found
    if [ "$collections_found" = false ]; then
        log "WARNING" "No 'Collection' directories were processed"
    fi

    return 0
}

# Main function
main() {
    local source_dir=""
    local target_dir=""
    local dry_run=false
    local force=false

    # Check for required commands
    log "INFO" "Checking required dependencies..."
    check_command "find" || return 1
    check_command "cp" || return 1
    check_command "rm" || return 1

    # Parse options using getopts
    while getopts ":dfvh-:" opt; do
        case ${opt} in
            d)
                dry_run=true
                ;;
            f)
                force=true
                ;;
            v)
                VERBOSE=true
                ;;
            h)
                usage
                ;;
            -)
                case "${OPTARG}" in
                    dry-run)
                        dry_run=true
                        ;;
                    force)
                        force=true
                        ;;
                    verbose)
                        VERBOSE=true
                        ;;
                    help)
                        usage
                        ;;
                    *)
                        log "ERROR" "Invalid option: --${OPTARG}"
                        usage
                        ;;
                esac
                ;;
            \?)
                log "ERROR" "Invalid option: -$OPTARG"
                usage
                ;;
            :)
                log "ERROR" "Option -$OPTARG requires an argument."
                usage
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Get source and target directories
    if [ $# -lt 1 ]; then
        log "ERROR" "No source directory provided"
        usage
    elif [ $# -gt 2 ]; then
        log "ERROR" "Too many arguments provided"
        usage
    fi

    source_dir="$1"
    if [ $# -eq 2 ]; then
        target_dir="$2"
    else
        target_dir="$source_dir"
    fi

    # Check if the provided paths exist and are directories or symbolic links to directories
    if [ ! -d "$source_dir" ] && [ ! -L "$source_dir" ]; then
        log "ERROR" "Source directory '$source_dir' is not a valid directory"
        return 1
    fi

    if [ ! -d "$target_dir" ] && [ ! -L "$target_dir" ]; then
        log "ERROR" "Target directory '$target_dir' is not a valid directory"
        return 1
    fi

    # Check if user has write permissions to target directory
    if [ ! -w "$target_dir" ]; then
        log "ERROR" "No write permission to target directory '$target_dir'"
        return 1
    fi

    # Convert to absolute paths (handle symbolic links properly)
    source_dir=$(get_absolute_path "$source_dir") || return 1
    target_dir=$(get_absolute_path "$target_dir") || return 1

    # Check disk space
    check_disk_space "$source_dir" "$target_dir" "$dry_run" "$force" || return 1

    # Check if source and target are the same directory
    if [ "$source_dir" = "$target_dir" ]; then
        log "NORMAL" "Source and target directories are the same: $source_dir"
    else
        log "NORMAL" "Source directory: $source_dir"
        log "NORMAL" "Target directory: $target_dir"
    fi

    # Detect if source and target are on different filesystems
    if [ "$source_dir" != "$target_dir" ] && [ "$dry_run" = false ]; then
        local source_fs
        local target_fs

        if source_fs=$(df -P "$source_dir" 2>/dev/null | awk 'NR==2 {print $1}') && \
           target_fs=$(df -P "$target_dir" 2>/dev/null | awk 'NR==2 {print $1}'); then
            if [ "$source_fs" != "$target_fs" ]; then
                log "INFO" "Source and target are on different filesystems. Using cp+rm instead of mv."
            fi
        else
            log "WARNING" "Could not determine filesystem types - using cp+rm to be safe"
        fi
    fi

    if [ "$dry_run" = true ]; then
        log "NORMAL" "DRY RUN MODE: No files will be moved"
        echo "============================================"
    fi

    # Change to the source directory
    cd "$source_dir" || return 1

    # Process collections
    process_collections "$source_dir" "$target_dir" "$dry_run"
    return $?
}

# -----------------------------------------------------------------------------
# Script Execution
# -----------------------------------------------------------------------------

# Set up trap for clean exit
trap 'cleanup $?' EXIT
trap 'cleanup "with an error"' ERR

# Execute main function
main "$@"
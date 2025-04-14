#!/bin/bash

# Exit on error, undefined variable, and error in piped commands
set -euo pipefail

# Version
VERSION="1.0.0"

# Usage function
usage() {
    echo "Collection Directory Reorganizer v${VERSION}"
    echo ""
    echo "Usage: $0 [-d] [-h] [-v] [-f] source_directory [target_directory]"
    echo "This script will find all subdirectories ending with 'Collection' in the source directory"
    echo "and move all their subdirectories to either the source directory or the specified target directory."
    echo ""
    echo "Options:"
    echo "  -d, --dry-run    Show what would be moved without performing actual operations"
    echo "  -f, --force      Skip all prompts and force operations"
    echo "  -v, --verbose    Enable verbose output"
    echo "  -h, --help       Display this help message and exit"
    echo ""
    echo "Compatible with TrueNAS Scale and Unraid OS"
    exit 1
}

# Function to log messages
log() {
    local level="$1"
    local message="$2"

    case "$level" in
        "INFO")
            if [ "$VERBOSE" = true ]; then
                echo "[INFO] $message"
            fi
            ;;
        "WARNING")
            echo "[WARNING] $message" >&2
            ;;
        "ERROR")
            echo "[ERROR] $message" >&2
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to clean up on exit or error
cleanup() {
    # Return to original directory
    cd "$ORIGINAL_DIR" 2>/dev/null || true
    log "INFO" "Script exited ${1:-normally}"
}

# Check for command presence
check_command() {
    command -v "$1" >/dev/null 2>&1 || { log "ERROR" "Required command '$1' not found. Please install it."; return 1; }
    return 0
}

# Function to process collection directories
process_collections() {
    local source_dir="$1"
    local target_dir="$2"
    local dry_run="$3"
    local dirs_moved=0
    local dirs_skipped=0
    local errors=0
    local collections_found=false

    # Use find with appropriate options (-L to follow symbolic links)
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

        # Find all subdirectories within the collection directory
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

            # Check if source directory is readable
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
                if [ "$VERBOSE" = true ]; then
                    cp -a "$subdir" "$target_dir/" && rm -rf "$subdir"
                else
                    cp -a "$subdir" "$target_dir/" 2>/dev/null && rm -rf "$subdir" 2>/dev/null
                fi

                if [ -d "$target_dir/$subdir_name" ]; then
                    log "NORMAL" "Successfully moved: $subdir_name"
                    dirs_moved=$((dirs_moved + 1))
                else
                    log "ERROR" "Error moving: $subdir_name"
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
    local SOURCE_DIR=""
    local TARGET_DIR=""
    local DRY_RUN=false
    local FORCE=false
    VERBOSE=false

    # Check for required commands
    check_command "find" || return 1
    check_command "cp" || return 1
    check_command "rm" || return 1

    # Parse options using getopts
    while getopts ":dfvh-:" opt; do
        case ${opt} in
            d)
                DRY_RUN=true
                ;;
            f)
                FORCE=true
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
                        DRY_RUN=true
                        ;;
                    force)
                        FORCE=true
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

    SOURCE_DIR="$1"
    if [ $# -eq 2 ]; then
        TARGET_DIR="$2"
    else
        TARGET_DIR="$SOURCE_DIR"
    fi

    # Check if the provided paths exist and are directories or symbolic links to directories
    if [ ! -d "$SOURCE_DIR" ] && [ ! -L "$SOURCE_DIR" ]; then
        log "ERROR" "Source directory '$SOURCE_DIR' is not a valid directory"
        return 1
    fi

    if [ ! -d "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
        log "ERROR" "Target directory '$TARGET_DIR' is not a valid directory"
        return 1
    fi

    # Check if user has write permissions to target directory
    if [ ! -w "$TARGET_DIR" ]; then
        log "ERROR" "No write permission to target directory '$TARGET_DIR'"
        return 1
    fi

    # Always check disk space for information purposes (regardless of FORCE flag)
    local SOURCE_SIZE
    local TARGET_AVAIL
    SOURCE_SIZE=$(du -s "$SOURCE_DIR" | awk '{print $1}')
    TARGET_AVAIL=$(df --no-sync -k "$TARGET_DIR" 2>/dev/null | awk 'NR==2 {print $4}')

    # If df with --no-sync fails, try without it (for BSD-based systems like TrueNAS)
    if [ $? -ne 0 ]; then
        TARGET_AVAIL=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $4}')
    fi

    if [ "$TARGET_AVAIL" -lt "$SOURCE_SIZE" ]; then
        log "WARNING" "Target directory may not have enough available space"
        log "WARNING" "Source size: $(($SOURCE_SIZE / 1024)) MB, Target available: $(($TARGET_AVAIL / 1024)) MB"

        # Only prompt if we're going to actually perform operations (not dry run)
        # and user hasn't explicitly forced operations
        if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "NORMAL" "Operation cancelled by user"
                return 1
            fi
        elif [ "$DRY_RUN" = false ] && [ "$FORCE" = true ]; then
            log "WARNING" "Continuing despite space concerns (force mode enabled)"
        fi
        # If it's a dry run, just show the warning but don't prompt or proceed with operations
    fi

    # Convert to absolute paths (handle symbolic links properly)
    SOURCE_DIR=$(cd -P "$(readlink -f "$SOURCE_DIR")" && pwd)
    TARGET_DIR=$(cd -P "$(readlink -f "$TARGET_DIR")" && pwd)

    # Check if source and target are the same directory
    if [ "$SOURCE_DIR" = "$TARGET_DIR" ]; then
        log "NORMAL" "Source and target directories are the same: $SOURCE_DIR"
    else
        log "NORMAL" "Source directory: $SOURCE_DIR"
        log "NORMAL" "Target directory: $TARGET_DIR"
    fi

    if [ "$DRY_RUN" = true ]; then
        log "NORMAL" "DRY RUN MODE: No files will be moved"
        echo "============================================"
    fi

    # Verify we can handle potential filesystem-specific issues
    if [ "$SOURCE_DIR" != "$TARGET_DIR" ] && [ "$DRY_RUN" = false ]; then
        # Check if source and target are on different filesystems
        local SOURCE_FS
        local TARGET_FS
        SOURCE_FS=$(df -P "$SOURCE_DIR" | awk 'NR==2 {print $1}')
        TARGET_FS=$(df -P "$TARGET_DIR" | awk 'NR==2 {print $1}')

        if [ "$SOURCE_FS" != "$TARGET_FS" ]; then
            log "INFO" "Source and target are on different filesystems. Using cp+rm instead of mv."
        fi
    fi

    # Change to the source directory
    cd "$SOURCE_DIR" || return 1

    # Process collections
    process_collections "$SOURCE_DIR" "$TARGET_DIR" "$DRY_RUN"
    return $?
}

# Store original directory
ORIGINAL_DIR=$(pwd)

# Set up trap for clean exit
trap 'cleanup $?' EXIT
trap 'cleanup "with an error"' ERR

# Make VERBOSE a global variable
VERBOSE=false

# Execute main function
main "$@"

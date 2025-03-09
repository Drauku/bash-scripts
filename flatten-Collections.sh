#!/bin/bash

# Exit on error, undefined variable, and error in piped commands
set -euo pipefail

# Usage function
usage() {
    echo "Usage: $0 [-d] [-h] source_directory [target_directory]"
    echo "This script will find all subdirectories ending with 'Collection' in the source directory"
    echo "and move all their subdirectories to either the source directory or the specified target directory."
    echo ""
    echo "Options:"
    echo "  -d, --dry-run    Show what would be moved without performing actual operations"
    echo "  -h, --help       Display this help message and exit"
    exit 1
}

# Function to clean up on exit or error
cleanup() {
    # Return to original directory
    cd "$ORIGINAL_DIR" 2>/dev/null || true
    echo "Script exited ${1:-normally}"
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

    # Find all directories ending with "Collection"
    local collections
    collections=$(find . -type d -maxdepth 1 -name "*Collection" | sort)

    # Check if any collections were found
    if [ -z "$collections" ]; then
        echo "No directories ending with 'Collection' found in $source_dir"
        return 0
    fi

    # Process each collection
    echo "$collections" | while IFS= read -r collection_dir; do
        collections_found=true
        echo "Processing: $collection_dir"

        # Check if collection directory is readable
        if [ ! -r "$collection_dir" ]; then
            echo "  Error: Cannot read collection directory '$collection_dir' (permission denied)"
            errors=$((errors + 1))
            continue
        fi

        # Find all subdirectories within the collection directory
        local subdirs
        subdirs=$(find "$collection_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

        # Check if any subdirectories were found
        if [ -z "$subdirs" ]; then
            echo "  No subdirectories found in $collection_dir"
            continue
        fi

        echo "$subdirs" | while IFS= read -r subdir; do
            local subdir_name
            subdir_name=$(basename "$subdir")

            # Check if a directory with the same name already exists in the target directory
            if [ -d "$target_dir/$subdir_name" ]; then
                echo "  WARNING: Directory '$subdir_name' already exists in the target directory. Skipping."
                dirs_skipped=$((dirs_skipped + 1))
                continue
            fi

            # Check if source directory is readable
            if [ ! -r "$subdir" ]; then
                echo "  Error: Cannot read source '$subdir' (permission denied)"
                errors=$((errors + 1))
                continue
            fi

            # Display the move operation
            echo "  MOVE: '$subdir' → '$target_dir/$subdir_name'"

            # Perform the move if not in dry run mode
            if [ "$dry_run" = false ]; then
                if mv "$subdir" "$target_dir/" 2>/dev/null; then
                    echo "  Successfully moved: $subdir_name"
                    dirs_moved=$((dirs_moved + 1))
                else
                    echo "  Error moving: $subdir_name"
                    errors=$((errors + 1))
                fi
            else
                dirs_moved=$((dirs_moved + 1))
            fi
        done

        echo "Completed processing: $collection_dir"
        echo "------------------------------------------"
    done

    # Show summary
    if [ "$dry_run" = true ]; then
        echo "============================================"
        echo "DRY RUN COMPLETE: No files were moved"
        echo "Would move: $dirs_moved directories"
        echo "Would skip: $dirs_skipped directories"
        if [ $errors -gt 0 ]; then
            echo "Potential errors: $errors"
        fi
    else
        echo "Script execution completed"
        echo "Directories moved: $dirs_moved"
        echo "Directories skipped: $dirs_skipped"
        if [ $errors -gt 0 ]; then
            echo "Errors encountered: $errors"
            return 1
        fi
    fi

    # Verify at least one collection directory was found
    if [ "$collections_found" = false ]; then
        echo "Warning: No 'Collection' directories were processed"
    fi

    return 0
}

# Main function
main() {
    local SOURCE_DIR=""
    local TARGET_DIR=""
    local DRY_RUN=false

    # Parse options using getopts
    while getopts ":dh-:" opt; do
        case ${opt} in
            d)
                DRY_RUN=true
                ;;
            h)
                usage
                ;;
            -)
                case "${OPTARG}" in
                    dry-run)
                        DRY_RUN=true
                        ;;
                    help)
                        usage
                        ;;
                    *)
                        echo "Invalid option: --${OPTARG}" >&2
                        usage
                        ;;
                esac
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                usage
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Get source and target directories
    if [ $# -lt 1 ]; then
        echo "Error: No source directory provided" >&2
        usage
    elif [ $# -gt 2 ]; then
        echo "Error: Too many arguments provided" >&2
        usage
    fi

    SOURCE_DIR="$1"
    if [ $# -eq 2 ]; then
        TARGET_DIR="$2"
    else
        TARGET_DIR="$SOURCE_DIR"
    fi

    # Check if the provided paths exist and are directories
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Error: Source directory '$SOURCE_DIR' is not a valid directory" >&2
        return 1
    fi

    if [ ! -d "$TARGET_DIR" ]; then
        echo "Error: Target directory '$TARGET_DIR' is not a valid directory" >&2
        return 1
    fi

    # Check if user has write permissions to target directory
    if [ ! -w "$TARGET_DIR" ]; then
        echo "Error: No write permission to target directory '$TARGET_DIR'" >&2
        return 1
    fi

    # Check for sufficient disk space in target directory
    local SOURCE_SIZE
    local TARGET_AVAIL
    SOURCE_SIZE=$(du -s "$SOURCE_DIR" | awk '{print $1}')
    TARGET_AVAIL=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $4}')

    if [ "$TARGET_AVAIL" -lt "$SOURCE_SIZE" ]; then
        echo "Warning: Target directory may not have enough available space" >&2
        echo "Source size: $(($SOURCE_SIZE / 1024)) MB, Target available: $(($TARGET_AVAIL / 1024)) MB" >&2

        if [ "$DRY_RUN" = false ]; then
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Operation cancelled by user" >&2
                return 1
            fi
        fi
    fi

    # Convert to absolute paths
    SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)
    TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

    # Check if source and target are the same directory
    if [ "$SOURCE_DIR" = "$TARGET_DIR" ]; then
        echo "Source and target directories are the same: $SOURCE_DIR"
    else
        echo "Source directory: $SOURCE_DIR"
        echo "Target directory: $TARGET_DIR"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN MODE: No files will be moved"
        echo "============================================"
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

# Execute main function
main "$@"

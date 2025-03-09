#!/bin/bash

# Exit on error, undefined variable, and error in piped commands
set -euo pipefail

# Usage function
usage() {
    echo "Usage: $0 <source_directory_path> [target_directory_path] [--dry-run]"
    echo "This script will find all subdirectories ending with 'Collection' in the source directory"
    echo "and move all their subdirectories to either the source directory or the specified target directory."
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be moved without performing actual operations"
    exit 1
}

# Function to clean up on exit or error
cleanup() {
    # Return to original directory
    cd "$ORIGINAL_DIR" 2>/dev/null || true
    echo "Script exited ${1:-normally}"
}

# Set up trap for clean exit
ORIGINAL_DIR=$(pwd)
trap 'cleanup $?' EXIT
trap 'cleanup "with an error"' ERR

# Initialize variables
SOURCE_DIR=""
TARGET_DIR=""
DRY_RUN=false
COLLECTION_DIRS_FOUND=false
DIRS_MOVED=0
DIRS_SKIPPED=0
ERRORS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1"
            usage
            ;;
        *)
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            elif [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$1"
            else
                echo "Error: Too many arguments provided"
                usage
            fi
            shift
            ;;
    esac
done

# Check if source directory path is provided
if [ -z "$SOURCE_DIR" ]; then
    echo "Error: No source directory provided"
    usage
fi

# Set target directory - either the provided target or same as source
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$SOURCE_DIR"
fi

# Check if the provided paths exist and are directories
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' is not a valid directory"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' is not a valid directory"
    exit 1
fi

# Check if user has write permissions to target directory
if [ ! -w "$TARGET_DIR" ]; then
    echo "Error: No write permission to target directory '$TARGET_DIR'"
    exit 1
fi

# Check for sufficient disk space in target directory
SOURCE_SIZE=$(du -s "$SOURCE_DIR" | awk '{print $1}')
TARGET_AVAIL=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $4}')

if [ "$TARGET_AVAIL" -lt "$SOURCE_SIZE" ]; then
    echo "Warning: Target directory may not have enough available space"
    echo "Source size: $(($SOURCE_SIZE / 1024)) MB, Target available: $(($TARGET_AVAIL / 1024)) MB"

    if [ "$DRY_RUN" = false ]; then
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled by user"
            exit 1
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
cd "$SOURCE_DIR" || exit 1

# Find all directories ending with "Collection"
COLLECTIONS=$(find . -type d -maxdepth 1 -name "*Collection" | sort)

# Check if any collections were found
if [ -z "$COLLECTIONS" ]; then
    echo "No directories ending with 'Collection' found in $SOURCE_DIR"
    exit 0
fi

# Process each collection
echo "$COLLECTIONS" | while IFS= read -r collection_dir; do
    COLLECTION_DIRS_FOUND=true
    echo "Processing: $collection_dir"

    # Check if collection directory is readable
    if [ ! -r "$collection_dir" ]; then
        echo "  Error: Cannot read collection directory '$collection_dir' (permission denied)"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Find all subdirectories within the collection directory
    SUBDIRS=$(find "$collection_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

    # Check if any subdirectories were found
    if [ -z "$SUBDIRS" ]; then
        echo "  No subdirectories found in $collection_dir"
        continue
    fi

    echo "$SUBDIRS" | while IFS= read -r subdir; do
        subdir_name=$(basename "$subdir")

        # Check if a directory with the same name already exists in the target directory
        if [ -d "$TARGET_DIR/$subdir_name" ]; then
            echo "  WARNING: Directory '$subdir_name' already exists in the target directory. Skipping."
            DIRS_SKIPPED=$((DIRS_SKIPPED + 1))
            continue
        fi

        # Check if source directory is readable
        if [ ! -r "$subdir" ]; then
            echo "  Error: Cannot read source '$subdir' (permission denied)"
            ERRORS=$((ERRORS + 1))
            continue
        fi

        # Display the move operation
        echo "  MOVE: '$subdir' → '$TARGET_DIR/$subdir_name'"

        # Perform the move if not in dry run mode
        if [ "$DRY_RUN" = false ]; then
            if mv "$subdir" "$TARGET_DIR/" 2>/dev/null; then
                echo "  Successfully moved: $subdir_name"
                DIRS_MOVED=$((DIRS_MOVED + 1))
            else
                echo "  Error moving: $subdir_name"
                ERRORS=$((ERRORS + 1))
            fi
        else
            DIRS_MOVED=$((DIRS_MOVED + 1))
        fi
    done

    echo "Completed processing: $collection_dir"
    echo "------------------------------------------"
done

# Show summary
if [ "$DRY_RUN" = true ]; then
    echo "============================================"
    echo "DRY RUN COMPLETE: No files were moved"
    echo "Would move: $DIRS_MOVED directories"
    echo "Would skip: $DIRS_SKIPPED directories"
    if [ $ERRORS -gt 0 ]; then
        echo "Potential errors: $ERRORS"
    fi
else
    echo "Script execution completed"
    echo "Directories moved: $DIRS_MOVED"
    echo "Directories skipped: $DIRS_SKIPPED"
    if [ $ERRORS -gt 0 ]; then
        echo "Errors encountered: $ERRORS"
        exit 1
    fi
fi

# Verify at least one collection directory was found
if [ "$COLLECTION_DIRS_FOUND" = false ]; then
    echo "Warning: No 'Collection' directories were processed"
fi

#!/bin/bash

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

# Initialize variables
SOURCE_DIR=""
TARGET_DIR=""
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
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
    echo "Error: Source directory $SOURCE_DIR is not a valid directory"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory $TARGET_DIR is not a valid directory"
    exit 1
fi

# Convert to absolute paths
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

echo "Source directory: $SOURCE_DIR"
echo "Target directory: $TARGET_DIR"
if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN MODE: No files will be moved"
    echo "============================================"
fi

# Change to the source directory
cd "$SOURCE_DIR" || exit 1

# Find all directories ending with "Collection"
find . -type d -maxdepth 1 -name "*Collection" | while read -r collection_dir; do
    echo "Processing: $collection_dir"

    # Find all subdirectories within the collection directory
    find "$collection_dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
        subdir_name=$(basename "$subdir")

        # Check if a directory with the same name already exists in the target directory
        if [ -d "$TARGET_DIR/$subdir_name" ]; then
            echo "  WARNING: Directory '$subdir_name' already exists in the target directory. Would be skipped."
        else
            # Display the move operation
            echo "  MOVE: '$subdir' → '$TARGET_DIR/$subdir_name'"

            # Perform the move if not in dry run mode
            if [ "$DRY_RUN" = false ]; then
                mv "$subdir" "$TARGET_DIR/"

                # Check if move was successful
                if [ $? -eq 0 ]; then
                    echo "  Successfully moved: $subdir_name"
                else
                    echo "  Error moving: $subdir_name"
                fi
            fi
        fi
    done

    echo "Completed processing: $collection_dir"
    echo "------------------------------------------"
done

if [ "$DRY_RUN" = true ]; then
    echo "============================================"
    echo "DRY RUN COMPLETE: No files were moved"
else
    echo "Script execution completed"
fi

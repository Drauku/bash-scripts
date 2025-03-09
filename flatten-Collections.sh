#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 <source_directory_path> [target_directory_path]"
    echo "This script will find all subdirectories ending with 'Collection' in the source directory"
    echo "and move all their subdirectories to either the source directory or the specified target directory."
    exit 1
}

# Check if source directory path is provided
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

SOURCE_DIR="$1"

# Set target directory - either the provided target or same as source
if [ "$#" -eq 2 ]; then
    TARGET_DIR="$2"
else
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

# Change to the source directory
cd "$SOURCE_DIR" || exit 1

# Find all directories ending with "Collection"
find . -type d -maxdepth 1 -name "*Collection" | while read -r collection_dir; do
    echo "Processing: $collection_dir"

    # Find all subdirectories within the collection directory
    find "$collection_dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
        subdir_name=$(basename "$subdir")
        echo "  Moving: $subdir_name from $collection_dir to $TARGET_DIR"

        # Check if a directory with the same name already exists in the target directory
        if [ -d "$TARGET_DIR/$subdir_name" ]; then
            echo "  Warning: Directory '$subdir_name' already exists in the target directory. Skipping."
        else
            # Move the subdirectory to the target directory
            mv "$subdir" "$TARGET_DIR/"

            # Check if move was successful
            if [ $? -eq 0 ]; then
                echo "  Successfully moved: $subdir_name"
            else
                echo "  Error moving: $subdir_name"
            fi
        fi
    done

    echo "Completed processing: $collection_dir"
done

echo "Script execution completed"

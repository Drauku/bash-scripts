#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 <parent_directory_path>"
    echo "This script will find all subdirectories containing 'Collection' in their name"
    echo "and move all their subdirectories up to the parent directory."
    exit 1
}

# Check if directory path is provided
if [ "$#" -ne 1 ]; then
    usage
fi

PARENT_DIR="$1"

# Check if the provided path exists and is a directory
if [ ! -d "$PARENT_DIR" ]; then
    echo "Error: $PARENT_DIR is not a valid directory"
    exit 1
fi

# Change to the parent directory
cd "$PARENT_DIR" || exit 1

# Find all directories with "Collection" in their name
find . -type d -maxdepth 1 -name "*Collection*" | while read -r collection_dir; do
    echo "Processing: $collection_dir"

    # Find all subdirectories within the collection directory
    find "$collection_dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
        subdir_name=$(basename "$subdir")
        echo "  Moving: $subdir_name from $collection_dir to $PARENT_DIR"

        # Check if a directory with the same name already exists in the parent directory
        if [ -d "$PARENT_DIR/$subdir_name" ]; then
            echo "  Warning: Directory '$subdir_name' already exists in the parent directory. Skipping."
        else
            # Move the subdirectory to the parent directory
            mv "$subdir" "$PARENT_DIR/"

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
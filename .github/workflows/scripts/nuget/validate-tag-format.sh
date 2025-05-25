#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Optional: uncomment if you want to be stricter about unset variables
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -o pipefail

# --- Configuration ---
TAG_NAME="$1"
# Regex for strict X.Y.Z version format (e.g., 1.0.0, 0.2.10, 123.45.678)
version_regex='^[0-9]+\.[0-9]+\.[0-9]+$'
# Explicit string often used to indicate no tag was found upstream
no_tag_marker="No tag"
# Target branch for validation
target_branch="master"
# GitHub Actions specific exit code for neutral outcome (skip)
neutral_exit_code=78

echo "Info: Received potential tag name: '${TAG_NAME}'"

# --- Branch Validation ---
echo "Info: Checking current branch..."
# Get the current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$target_branch" ]; then
    echo "Validation skipped: Current branch is '${current_branch}', not '${target_branch}'. Exiting neutrally."
    exit $neutral_exit_code
else
    echo "Info: Current branch is '${target_branch}'. Proceeding with tag validation."
fi

# --- Initial Tag Validation (Format, Empty, Marker) ---
if [[ -z "$TAG_NAME" ]]; then
    echo "Validation failed: No tag name provided (argument was empty). Exiting neutrally."
    exit $neutral_exit_code
elif [ "$TAG_NAME" == "$no_tag_marker" ]; then
    echo "Validation failed: Tag explicitly indicated as '${no_tag_marker}'. Exiting neutrally."
    exit $neutral_exit_code
elif ! [[ "$TAG_NAME" =~ $version_regex ]]; then
    echo "Validation failed: Input tag '${TAG_NAME}' format is invalid. Expected strictly X.Y.Z format. Exiting neutrally."
    exit $neutral_exit_code
else
    echo "Info: Input tag '${TAG_NAME}' format is valid (X.Y.Z)."
    # Tag format is valid, proceed to compare with existing Git tags.
fi

# --- Fetch and Compare with Existing Git Tags ---

echo "Info: Fetching latest tags from remote repository..."
# Use --force to ensure local tags are updated even if they exist
# Use --prune to remove local refs that no longer exist on the remote
# Handle potential fetch failure
if ! git fetch --tags --force --prune; then
    echo "Error: Failed to fetch tags from the remote repository. Cannot compare versions."
    exit 1 # Exit with a non-neutral code indicating a real failure
fi
echo "Info: Fetch complete."

echo "Info: Listing existing tags and finding highest X.Y.Z version..."
# List all local tags (now updated from remote), filter for X.Y.Z, sort, get highest
# Use process substitution and handle case where no matching tags are found
highest_existing_tag=$(git tag --list | grep -E "$version_regex" | sort -V | tail -n 1 || true)
# The '|| true' prevents script exit if grep finds no matching tags (pipefail/set -e would otherwise trigger)

if [ -z "$highest_existing_tag" ]; then
    echo "Info: No existing tags with X.Y.Z format found in the repository."
    echo "Info: Input tag '${TAG_NAME}' is considered the first valid version."
    # Proceed since it's the first tag.
else
    echo "Info: Highest existing X.Y.Z tag found: '${highest_existing_tag}'"

    # Compare the input tag with the highest existing tag.
    # Check for equality first.
    if [ "$TAG_NAME" == "$highest_existing_tag" ]; then
        echo "Validation succeeded. Tag is highest version and is new. Exiting successfully."
        exit 0
    fi

    # If not equal, check if the input tag is strictly greater using version sort.
    # Combine the new tag and the highest existing tag, sort them by version.
    # The strictly newer tag *must* appear last in the sorted list.
    sorted_versions=$(printf "%s\n%s" "$highest_existing_tag" "$TAG_NAME" | sort -V)
    highest_overall=$(echo "$sorted_versions" | tail -n 1)

    if [ "$TAG_NAME" != "$highest_overall" ]; then
        # If the new tag is NOT the highest in the combined sorted list, it's older.
        echo "Validation failed: Input tag '${TAG_NAME}' is not strictly newer than the highest existing tag '${highest_existing_tag}'. Exiting neutrally."
        exit $neutral_exit_code
    else
        # New tag is the highest overall AND we already checked it's not equal.
         echo "Info: Input tag '${TAG_NAME}' is strictly newer than highest existing tag '${highest_existing_tag}'."
         # Proceed.
    fi
fi

# --- Final Success ---
# If the script reaches here, all checks passed.
echo "Validation passed: Tag '${TAG_NAME}' is valid, on branch '${current_branch}', and represents a new version."
# Add subsequent commands that should run only with a valid, new tag here.

exit 0 # Explicitly exit with 0 for success
#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Optional: uncomment if you want to be stricter about unset variables
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -o pipefail

FILENAME="github_refs.wd"

# --- File Existence Check ---
if [ ! -f "$FILENAME" ]; then
  # Try checking with GITHUB_WORKSPACE prefix if the simple name doesn't exist
  if [ -n "$GITHUB_WORKSPACE" ] && [ -f "${GITHUB_WORKSPACE}/${FILENAME}" ]; then
      FILENAME="${GITHUB_WORKSPACE}/${FILENAME}"
      echo "Info: Found file at ${FILENAME}"
  else
      echo "Error: The file ${FILENAME} (or ${GITHUB_WORKSPACE}/${FILENAME} if defined) does not exist."
      exit 1
  fi
fi
echo "Info: Reading data from ${FILENAME}"

# --- Read Data ---
# Read the first line (git reference) into the variable 'GIT_REFERENCE'
GIT_REFERENCE=$(sed -n '1p' "$FILENAME")

# Read the second line (raw tag info) into the variable 'RAW_GIT_TAG'
RAW_GIT_TAG=$(sed -n '2p' "$FILENAME")

# --- Validate and Process Data ---

# --- Validate GIT_REFERENCE ---
# 1. Check if empty
if [ -z "$GIT_REFERENCE" ]; then
  echo "Error: First line (GIT_REFERENCE) in ${FILENAME} is empty."
  exit 1
fi
echo "Info: Read GIT_REFERENCE='${GIT_REFERENCE}'"

# 2. Check if it matches a common Git reference format using regex
#    Allows:
#    - refs/... (e.g., refs/heads/main, refs/tags/v1.0.0, refs/pull/123/head)
#    - HEAD, FETCH_HEAD, ORIG_HEAD, MERGE_HEAD
#    - Full 40-character hexadecimal commit SHA
#    Note: This regex covers common cases but might not cover every obscure valid ref name.
ref_regex='^(refs/[^[:space:]]+|HEAD|FETCH_HEAD|ORIG_HEAD|MERGE_HEAD|[0-9a-fA-F]{40})$'

if ! [[ "$GIT_REFERENCE" =~ $ref_regex ]]; then
    echo "Error: The read GIT_REFERENCE ('${GIT_REFERENCE}') does not look like a standard Git reference."
    echo "       Expected formats: refs/..., HEAD, FETCH_HEAD, ORIG_HEAD, MERGE_HEAD, or a 40-char SHA."
    exit 1
fi
echo "Info: GIT_REFERENCE format validated successfully."

# --- Process RAW_GIT_TAG ---
GIT_TAG="" # Default to empty string (meaning no actual tag)
NO_TAG_MARKER="No tag"

if [ -n "$RAW_GIT_TAG" ]; then # Check if the second line had any content
    echo "Info: Read raw value from second line: '${RAW_GIT_TAG}'"
    if [ "$RAW_GIT_TAG" != "$NO_TAG_MARKER" ]; then
        # If the line is not empty AND it's not the "No tag" marker, treat it as the tag
        GIT_TAG="$RAW_GIT_TAG"
        echo "Info: Determined valid GIT_TAG='${GIT_TAG}'"
    else
        # The line explicitly contained "No tag"
        echo "Info: Second line indicates '${NO_TAG_MARKER}', setting GIT_TAG to empty."
        # GIT_TAG remains ""
    fi
else
    # The second line was empty
    echo "Info: Second line is empty, setting GIT_TAG to empty."
    # GIT_TAG remains ""
fi


# --- Export Variables ---
# Check if GITHUB_ENV is set and is a file (standard in GitHub Actions)
if [ -z "$GITHUB_ENV" ] || [ ! -f "$GITHUB_ENV" ]; then
    echo "Warning: GITHUB_ENV environment variable is not set or not a file. Skipping export."
    echo "Would have exported: GIT_REFERENCE=${GIT_REFERENCE}"
    echo "Would have exported: GIT_TAG=${GIT_TAG}"
else
    echo "Info: Exporting variables to ${GITHUB_ENV}"
    # Append the variables in the format required by GitHub Actions
    echo "GIT_REFERENCE=${GIT_REFERENCE}" >> "$GITHUB_ENV"
    echo "GIT_TAG=${GIT_TAG}" >> "$GITHUB_ENV" # Corrected export destination

    echo "Exported: GIT_REFERENCE=${GIT_REFERENCE}"
    echo "Exported: GIT_TAG=${GIT_TAG}"
fi

echo "Script finished successfully."

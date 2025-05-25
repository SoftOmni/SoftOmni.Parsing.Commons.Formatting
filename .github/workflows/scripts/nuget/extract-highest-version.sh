#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Optional: uncomment if you want to be stricter about unset variables
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -o pipefail

FILENAME="dotnet-versions.txt"
JSON_KEY="dotnet_version" # Key in the JSON containing the version array
GLOBAL_JSON_FILENAME="global.json" # Name of the file to generate

# --- Prerequisite Check: jq ---
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' command not found. Please install jq to parse the JSON file."
    exit 1
fi
echo "Info: 'jq' command found."

# --- File Existence Check ---
if [ ! -f "$FILENAME" ]; then
  # Try checking with GITHUB_WORKSPACE prefix if the simple name doesn't exist
  if [ -n "$GITHUB_WORKSPACE" ] && [ -f "${GITHUB_WORKSPACE}/${FILENAME}" ]; then
      FILENAME="${GITHUB_WORKSPACE}/${FILENAME}"
      echo "Info: Found versions file at ${FILENAME}"
  else
      echo "Error: The versions file ${FILENAME} (or ${GITHUB_WORKSPACE}/${FILENAME} if defined) does not exist."
      exit 1
  fi
fi
echo "Info: Processing versions from ${FILENAME}"

# --- JSON Validation and Data Extraction ---

# 1. Validate if the file is valid JSON
if ! jq empty "$FILENAME" > /dev/null 2>&1; then
    echo "Error: ${FILENAME} is not a valid JSON file."
    exit 1
fi
echo "Info: ${FILENAME} is valid JSON."

# 2. Validate if the specific key exists and is an array
if ! jq -e --arg key "$JSON_KEY" 'has($key) and (.[$key] | type == "array")' "$FILENAME" > /dev/null; then
    echo "Error: JSON file ${FILENAME} does not contain the key \"${JSON_KEY}\" or its value is not an array."
    exit 1
fi
echo "Info: JSON key \"${JSON_KEY}\" exists and is an array."

# --- Find ALL Valid Versions and Highest Version ---

# Regex to match .NET versions like netX.Y or netX.Y.Z
version_regex='^net[0-9]+\.[0-9]+(\.[0-9]+)?$'

extracted_versions=$(jq -r --arg key "$JSON_KEY" '.[$key][]' "$FILENAME")
if [ -z "$extracted_versions" ]; then
    echo "Error: The array under key \"${JSON_KEY}\" in ${FILENAME} is empty. No versions found."
    exit 1 # Exit if the versions array is empty
fi

# Filter for valid versions first
all_valid_net_versions=$(echo "$extracted_versions" | grep -E "$version_regex" || true)

if [ -z "$all_valid_net_versions" ]; then
  echo "Error: No valid versions matching the format '${version_regex}' found under key \"${JSON_KEY}\" in ${FILENAME}."
  exit 1
fi

echo "Info: Found valid raw versions:"
echo "$all_valid_net_versions" # Log all valid found versions

# Find the highest version among the valid ones
HIGHEST_NET_VERSION=$(echo "$all_valid_net_versions" | sort -Vr | head -n 1)
echo "Info: Highest raw version found: ${HIGHEST_NET_VERSION}"

# --- Extract Version Parts for Highest Version ---
VERSION_NUMERIC_PART=$(echo "$HIGHEST_NET_VERSION" | sed 's/^net//')
BASE_VERSION_XY=$(echo "$VERSION_NUMERIC_PART" | cut -d. -f1,2)
echo "Info: Base Major.Minor version (for global.json): ${BASE_VERSION_XY}"

# --- Convert Highest Version to X.Y.Z Format (for potential other uses) ---
if [[ "$VERSION_NUMERIC_PART" == *.*.* ]]; then
    HIGHEST_XYZ_VERSION="$VERSION_NUMERIC_PART"
elif [[ "$VERSION_NUMERIC_PART" == *.* ]]; then
    HIGHEST_XYZ_VERSION="${VERSION_NUMERIC_PART}.0"
else
    echo "Error: Could not parse version part '$VERSION_NUMERIC_PART' from '$HIGHEST_NET_VERSION' into X.Y or X.Y.Z format after stripping 'net'."
    exit 1
fi
echo "Highest valid .NET version (formatted as X.Y.Z): $HIGHEST_XYZ_VERSION"

# --- Generate global.json using HIGHEST X.Y format ---
echo "Info: Generating ${GLOBAL_JSON_FILENAME} with SDK version specification '${BASE_VERSION_XY}'..."
printf '{\n  "sdk": {\n    "version": "%s",\n    "rollForward": "latestFeature"\n  }\n}\n' "$BASE_VERSION_XY" > "$GLOBAL_JSON_FILENAME"
if [ ! -f "$GLOBAL_JSON_FILENAME" ]; then
    echo "Error: Failed to create ${GLOBAL_JSON_FILENAME}"
    exit 1
fi
echo "Info: Successfully generated ${GLOBAL_JSON_FILENAME}"
echo "Info: Content of ${GLOBAL_JSON_FILENAME}:"
cat "$GLOBAL_JSON_FILENAME"

# --- Prepare ALL versions list for setup-dotnet ---
# Convert all valid 'netX.Y.Z' or 'netX.Y' versions to 'X.Y' format for setup-dotnet input
# Use sort -u to ensure uniqueness
all_setup_versions_xy=$(echo "$all_valid_net_versions" | sed 's/^net//' | cut -d. -f1,2 | sort -u)

echo "Info: Versions prepared for setup-dotnet (X.Y format):"
echo "$all_setup_versions_xy"

# --- Export Variables and Outputs ---

# Check if GITHUB_OUTPUT is set and usable (preferred for multi-line)
if [ -n "$GITHUB_OUTPUT" ] && [ -f "$GITHUB_OUTPUT" ]; then
    echo "Info: Exporting ALL_DOTNET_VERSIONS_XY output for setup-dotnet..."
    # Use a delimiter that's unlikely to appear in the versions themselves
    # Use standard heredoc syntax for GITHUB_OUTPUT multi-line values
    {
        echo "ALL_DOTNET_VERSIONS_XY<<EOF"
        echo "$all_setup_versions_xy"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
    echo "Exported ALL_DOTNET_VERSIONS_XY output."
else
     echo "Warning: GITHUB_OUTPUT environment variable is not set or not a file. Cannot export multi-line ALL_DOTNET_VERSIONS_XY output."
fi

# Check if GITHUB_ENV is set and usable (for single-line highest version)
if [ -n "$GITHUB_ENV" ] && [ -f "$GITHUB_ENV" ]; then
    echo "Info: Exporting DOTNET_VERSION=${HIGHEST_XYZ_VERSION} to ${GITHUB_ENV}"
    echo "DOTNET_VERSION=${HIGHEST_XYZ_VERSION}" >> "${GITHUB_ENV}"
    echo "Exported: DOTNET_VERSION=${HIGHEST_XYZ_VERSION}"
else
    echo "Warning: GITHUB_ENV environment variable is not set or not a file. Skipping export of DOTNET_VERSION."
    echo "Would have exported: DOTNET_VERSION=${HIGHEST_XYZ_VERSION}"
fi


echo "Script finished successfully."
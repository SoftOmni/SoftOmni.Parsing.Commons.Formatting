#!/bin/bash

EXPECTED_VERSION="$1"
if [ -z "$EXPECTED_VERSION" ]; then
  echo "Error: No version argument provided. Please provide the expected version as a parameter."
  exit 1
fi

if ! [[ "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: The expected version argument must follow X.Y.Z format but did not: $EXPECTED_VERSION"
    exit 1
fi

set -e
SCRIPT_PATH=$(pwd)

# Find all .csproj files in the repository
PROJECT_FILES=$(find "$SCRIPT_PATH" -type f -name "*.csproj")

# Initialize an array to store found versions
VERSIONS=()

echo "Debug: Searching for <Version> tags in .csproj files..."
for PROJECT_FILE in $PROJECT_FILES; do
  # Extract single version tag content (ignore if not present)
  # Using awk is often more robust for XML-like structures than grep lookarounds
  TARGET=$(awk -F'[<>]' '/<Version>/ {print $3; exit}' "$PROJECT_FILE" || true)
  # Alternative using grep (original method)
  # TARGET=$(grep -oPm1 "(?<=<Version>)(.*)(?=</Version>)" "$PROJECT_FILE" || true)

  if [[ -n "$TARGET" ]]; then # Check if TARGET is not empty
      echo "Debug print: Found raw value '$TARGET' in $PROJECT_FILE"
      # Check if the extracted value strictly matches the version format
      if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Debug print: Adding valid version '$TARGET'"
        VERSIONS+=("$TARGET")
      else
        echo "Debug print: Ignoring non-matching value '$TARGET' in $PROJECT_FILE"
      fi
  else
      echo "Debug print: No <Version> tag found or tag is empty in $PROJECT_FILE"
  fi
done

NUMBER_OF_VERSIONS_FOUND="${#VERSIONS[@]}"
echo "Debug: Total valid versions found: $NUMBER_OF_VERSIONS_FOUND"

if [ "$NUMBER_OF_VERSIONS_FOUND" -eq "0" ]; then
  echo "Error: Did not find any valid <Version>X.Y.Z</Version> tags in any .csproj files. Aborting..."
  exit 1
fi

# Find unique versions among the valid ones found
mapfile -t UNIQUE_VERSIONS < <(printf "%s\n" "${VERSIONS[@]}" | sort -u)
NUMBER_OF_UNIQUE_VERSIONS="${#UNIQUE_VERSIONS[@]}"
echo "Debug: Unique versions found: ${UNIQUE_VERSIONS[*]}"

# Check if more than one *different* version exists
if [ "$NUMBER_OF_UNIQUE_VERSIONS" -ne 1 ]; then
    echo "Error: Multiple different dotnet versions found (${UNIQUE_VERSIONS[*]}). Ensure all projects use the same version. Aborting..."
    exit 1
fi

# If we get here, there is exactly one unique version across all relevant files
ACTUAL_VERSION="${UNIQUE_VERSIONS[0]}"
echo "Debug: Determined actual version: $ACTUAL_VERSION"

# Final comparison
if [ "$EXPECTED_VERSION" != "$ACTUAL_VERSION" ]; then
  echo "Error: Version mismatch. Expected '$EXPECTED_VERSION', but found '$ACTUAL_VERSION'. Aborting..."
  exit 1
fi

echo "Version check passed. Version: $ACTUAL_VERSION"

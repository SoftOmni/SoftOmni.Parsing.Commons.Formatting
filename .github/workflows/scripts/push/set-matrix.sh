#!/bin/bash
set -e
SCRIPT_PATH=$(pwd)

# Find all .csproj files in the repository
PROJECT_FILES=$(find "$SCRIPT_PATH" -type f -name "*.csproj")

# Initialize an array to store target frameworks
VERSIONS=()

for PROJECT_FILE in $PROJECT_FILES; do
  # Extract single target framework (ignore if not present)
  TARGET=$(grep -oPm1 "(?<=<TargetFramework>)(.*)(?=</TargetFramework>)" "$PROJECT_FILE" || true)
  if [ -n "$TARGET" ]; then
    VERSIONS+=("$TARGET")
  fi
  # Extract multiple target frameworks, if any
  MULTI=$(grep -oPm1 "(?<=<TargetFrameworks>)(.*)(?=</TargetFrameworks>)" "$PROJECT_FILE" || true)
  if [ -n "$MULTI" ]; then
    IFS=';' read -ra FRAMEWORKS <<< "$MULTI"
    for f in "${FRAMEWORKS[@]}"; do
      VERSIONS+=("$f")
    done
  fi
done

# Remove duplicate entries and sort them
mapfile -t UNIQUE_VERSIONS < <(printf "%s\n" "${VERSIONS[@]}" | sort -u)

if [ ${#UNIQUE_VERSIONS[@]} -eq 0 ]; then
  echo "No .NET versions found in projects."
  MATRIX_JSON="{\"dotnet_version\": []}"
  HIGHEST_VERSION=""
else
  # Build a JSON array from the unique versions (e.g. ["net6.0","net7.0"])
  JSON_ARRAY=$(printf '"%s",' "${UNIQUE_VERSIONS[@]}")
  JSON_ARRAY="[${JSON_ARRAY%,}]"
  MATRIX_JSON="{\"dotnet_version\": $JSON_ARRAY}"

  # Determine the highest version.
  # Remove "net" prefix, sort numerically in reverse, and then prepend "net" again.
  HIGHEST_NUM=$(printf "%s\n" "${UNIQUE_VERSIONS[@]}" | sed 's/^net//' | sort -rV | head -n 1)
  HIGHEST_VERSION="net${HIGHEST_NUM}"
fi

echo "Matrix: $MATRIX_JSON"
echo "Highest version: $HIGHEST_VERSION"
# Write outputs using the new environment file syntax:
echo "matrix=$MATRIX_JSON" >> "$GITHUB_OUTPUT"
echo "highest=$HIGHEST_VERSION" >> "$GITHUB_OUTPUT"

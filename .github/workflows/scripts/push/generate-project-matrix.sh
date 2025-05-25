#!/bin/bash

# Find all test projects (adjust the pattern/path as needed)
echo "Finding test projects..."
test_projects=$(find "${1}" -type f -name "*Tests.csproj")
echo "Found projects: $test_projects"

# Store the JSON input as a variable without using echo
dotnet_versions_json="$2"

# Print the raw JSON for debugging
echo "Raw .NET versions JSON: $dotnet_versions_json"

# Extract .NET versions properly without stripping quotes
versions=$(jq -r '.dotnet_version[]' <<< "$dotnet_versions_json")

# Convert JSON array elements into a Bash array
versions_array=()
while IFS= read -r version; do
    versions_array+=("$version")
done <<< "$versions"

# Build a JSON array of matrix entries.
matrix_entries="[]"
for project in $test_projects; do
  for version in "${versions_array[@]}"; do
    matrix_entries=$(jq -c --arg v "$version" --arg p "$project" '. + [{"dotnet_version": $v, "test_project": $p}]' <<< "$matrix_entries")
  done
done

echo "Generated test matrix:"
echo "$matrix_entries"

# Use GitHub Actions environment file instead of deprecated ::set-output
echo "test-matrix=$(jq -c . <<< "$matrix_entries")" >> "$GITHUB_OUTPUT"

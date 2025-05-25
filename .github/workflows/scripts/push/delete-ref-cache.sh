#!/bin/bash
# delete-ref-cache.sh
#
# This script deletes the stored git reference cache using the GitHub API.
# It expects:
#   - GITHUB_BEARER_TOKEN: A GitHub token with sufficient permissions.
#   - GITHUB_REPOSITORY: The "owner/repo" identifier (automatically set in GitHub Actions).
#
# The cache key being used is "push-reference".

set -e

# Check if the required token is set
if [ -z "$GITHUB_BEARER_TOKEN" ]; then
  echo "Error: GITHUB_BEARER_TOKEN is not set."
  exit 1
fi

# Define variables
REPO="${GITHUB_REPOSITORY}"
API_URL="https://api.github.com/repos/${REPO}/actions/caches"
CACHE_KEY="push-reference"

echo "Listing caches for key: ${CACHE_KEY}"

# List caches with the specified key using the GitHub API.
response=$(curl -s -H "Authorization: Bearer ${GITHUB_BEARER_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API_URL}?key=${CACHE_KEY}")

# Use jq to parse the JSON response and extract the first cache id.
cache_id=$(echo "$response" | jq -r '.actions_caches[0].id // empty')

if [ -z "$cache_id" ]; then
  echo "No cache found with key ${CACHE_KEY}. Nothing to delete."
  exit 0
fi

echo "Found cache with id: ${cache_id}. Deleting cache..."

# Delete the cache using the GitHub API.
delete_response=$(curl -s -X DELETE -H "Authorization: Bearer ${GITHUB_BEARER_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API_URL}/${cache_id}")
  

# Parse the delete response to confirm the cache was successfully deleted
delete_status=$(echo "$delete_response" | jq -r '.message // empty')

if [ -n "$delete_status" ]; then
  echo "Deletion response: $delete_status"
else
  echo "Cache deletion confirmed."
fi

exit 0

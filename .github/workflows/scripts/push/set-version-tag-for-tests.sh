#!/bin/bash

set -e
git fetch --tags
TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null) || true
if [[ -n "$TAG" && "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  VERSION=$TAG
else
  COMMIT_HASH=$(git rev-parse --short HEAD)
  VERSION="0.0.0-$COMMIT_HASH"
fi

echo "VERSION=$VERSION" >> "$GITHUB_ENV"
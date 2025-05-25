#!/bin/bash

# Convert the current matrix target framework (e.g. net6.0) to an SDK version (e.g. 6.0.x)
sdk_version=$(echo "${1}" | sed 's/^net//').x
echo "Calculated .NET SDK version for test: $sdk_version"
echo "sdk_version=$sdk_version" >> "$GITHUB_OUTPUT"
echo "dotnet_sdk_version=${1}" >> "$GITHUB_OUTPUT"
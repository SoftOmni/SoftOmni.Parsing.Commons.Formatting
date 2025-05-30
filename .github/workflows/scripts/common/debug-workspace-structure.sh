#!/bin/bash

# .github/workflows/scripts/common/debug-workspace-structure.sh

# --- Configuration & Setup ---
set -e # Exit on error
# set -u # Treat unset variables as an error
set -o pipefail

WORKSPACE_ROOT="${1:-${GITHUB_WORKSPACE}}" # Use GITHUB_WORKSPACE if no arg is provided

if [ -z "${WORKSPACE_ROOT}" ] || [ ! -d "${WORKSPACE_ROOT}" ]; then
  echo "Error: WORKSPACE_ROOT is not set or is not a directory: '${WORKSPACE_ROOT}'"
  exit 1
fi

echo "--- Generic Workspace Structure Debug Script ---"
echo "Workspace Root: ${WORKSPACE_ROOT}"
echo "Current Directory (script execution): $(pwd)"
echo

echo "--- Top-Level Workspace Listing (depth 3) ---"
if command -v tree &> /dev/null; then
  tree -L 3 "${WORKSPACE_ROOT}"
else
  echo "Info: 'tree' command not found. Using 'find' for listing."
  find "${WORKSPACE_ROOT}" -maxdepth 3 -print
fi
echo

echo "--- Detailed Project Structure Inspection ---"
# Find all .csproj files, then derive project directories to inspect their bin/obj
# This assumes .csproj files are at the root of each project's directory
find "${WORKSPACE_ROOT}" -name "*.csproj" -print0 | while IFS= read -r -d $'\0' csproj_file; do
  project_dir=$(dirname "$csproj_file")
  # Heuristic to get a project name (might not be perfect for all structures)
  project_name_from_path=$(basename "$project_dir")
  # If csproj is named like the dir, use that, otherwise use dir name
  csproj_basename=$(basename "$csproj_file" .csproj)
  if [[ "$csproj_basename" == "$project_name_from_path" ]]; then
    display_project_name="$project_name_from_path"
  else
    display_project_name="${project_name_from_path} (csproj: ${csproj_basename})"
  fi


  echo "-----------------------------------------------------"
  echo "Inspecting Project: ${display_project_name} (found at ${project_dir})"
  echo "-----------------------------------------------------"

  # Check obj directory
  obj_dir="${project_dir}/obj"
  echo "--- Contents of ${obj_dir}: ---"
  if [ -d "$obj_dir" ]; then
    ls -la "$obj_dir"
    if command -v tree &> /dev/null; then
      tree -L 2 "$obj_dir"
    else
      echo "  (tree not available, listing using find)"
      find "$obj_dir" -maxdepth 2 -print
    fi
    # Specifically check for project.assets.json
    if [ -f "${obj_dir}/project.assets.json" ]; then
        echo "  Found: ${obj_dir}/project.assets.json"
    else
        echo "  Warning: ${obj_dir}/project.assets.json NOT FOUND."
    fi
  else
    echo "  Directory ${obj_dir} NOT FOUND."
  fi
  echo

  # Check bin/Release directory
  bin_release_dir="${project_dir}/bin/Release"
  echo "--- Contents of ${bin_release_dir}: ---"
  if [ -d "$bin_release_dir" ]; then
    ls -la "$bin_release_dir"
    if command -v tree &> /dev/null; then
      tree -L 2 "$bin_release_dir"
    else
      echo "  (tree not available, listing using find)"
      find "$bin_release_dir" -maxdepth 2 -print
    fi
  else
    echo "  Directory ${bin_release_dir} NOT FOUND."
  fi
  echo
done

echo "--- Verification: All project.assets.json files found in workspace ---"
assets_files_found=$(find "${WORKSPACE_ROOT}" -name project.assets.json -print)
if [ -n "$assets_files_found" ]; then
  echo "$assets_files_found"
else
  echo "No project.assets.json files found in workspace."
fi
echo

echo "--- Verification: All Release directories in bin folders in workspace ---"
release_dirs_found=$(find "${WORKSPACE_ROOT}" -type d -path "*/bin/Release" -print)
if [ -n "$release_dirs_found" ]; then
  echo "$release_dirs_found"
else
  echo "No */bin/Release directories found in workspace."
fi
echo

echo "Debug script finished."

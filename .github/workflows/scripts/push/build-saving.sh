#!/bin/bash

# .github/workflows/scripts/push/build-saving.sh

# --- Configuration & Setup ---
set -e
set -o pipefail

# --- Determine Mode (Single Version vs. All Versions) ---
MODE="single" # Default mode
if [ -z "$1" ]; then
  MODE="all"
  echo "Info: No .NET version specified. Script will process artifacts for all found versions."
else
  MODE="single"
  DOTNET_VERSION_ARG="$1"
  echo "Info: Specific .NET version requested: ${DOTNET_VERSION_ARG}"
fi

# --- Variable Initialization ---
SCRIPT_START_DIR=$(pwd)
projects_packaged=0
total_projects_found_in_artifacts=0

# --- Temporary Directory ---
TEMP_DIR=$(mktemp -d)
trap 'EXIT_CODE=$?; echo "Info: Cleaning up temporary packaging directory: ${TEMP_DIR}"; rm -rf "${TEMP_DIR}"; exit $EXIT_CODE' EXIT HUP INT QUIT PIPE TERM
echo "Info: Created temporary directory for packaging: ${TEMP_DIR}"

# --- Mode Specific Setup ---
if [ "$MODE" == "all" ]; then
  ARTIFACTS_ROOT_PATTERN="build-artifacts-net*.*"
  SEARCH_ROOT="."
  PATH_PATTERN="./${ARTIFACTS_ROOT_PATTERN}/*/bin/Release/net[0-9]*.[0-9]*"
  OUTPUT_ZIP="release_bin_assets_files_all_versions.zip"
  REPORTING_VERSION_TEXT="all found versions"

  if ! find . -maxdepth 1 -type d -name "${ARTIFACTS_ROOT_PATTERN}" -print -quit | grep -q .; then
    echo "Error: No artifact root directories matching '${ARTIFACTS_ROOT_PATTERN}' found in ${SCRIPT_START_DIR}."
    exit 1
  fi
  echo "Info: Searching for artifacts across all roots matching: ${ARTIFACTS_ROOT_PATTERN}"
else # MODE == "single"
  dotnet_version_regex='^net[0-9]+\.[0-9]+$'
  if [[ ! "$DOTNET_VERSION_ARG" =~ $dotnet_version_regex ]]; then
    echo "Error: Please provide the target .NET version in netX.Y format (e.g., net8.0)."
    exit 1
  fi
  DOTNET_VERSION="$DOTNET_VERSION_ARG"
  ARTIFACTS_ROOT_DIR="build-artifacts-${DOTNET_VERSION}"
  OUTPUT_ZIP="release_bin_assets_files_${DOTNET_VERSION}.zip"
  REPORTING_VERSION_TEXT="target framework '${DOTNET_VERSION}'"
  SEARCH_ROOT="${ARTIFACTS_ROOT_DIR}"
  PATH_PATTERN="*/bin/Release/${DOTNET_VERSION}"

  echo "Info: Target .NET Version: ${DOTNET_VERSION}"
  echo "Info: Searching for artifacts in root: ${ARTIFACTS_ROOT_DIR}"
  if [ ! -d "${ARTIFACTS_ROOT_DIR}" ]; then
    echo "Error: Artifacts root directory '${ARTIFACTS_ROOT_DIR}' not found in ${SCRIPT_START_DIR}."
    exit 1
  fi
fi

echo "Info: Output Zip File: ${OUTPUT_ZIP}"
echo "Info: Searching for final artifact directories..."
echo "Info: Search Root: '${SEARCH_ROOT}'"
echo "Info: Path Pattern: '${PATH_PATTERN}'"

while IFS= read -r -d $'\0' source_bin_dir; do
    total_projects_found_in_artifacts=$((total_projects_found_in_artifacts + 1))
    project_artifact_dir=$(dirname "$(dirname "$(dirname "$source_bin_dir")")")
    project_name=$(basename "$project_artifact_dir")
    source_dotnet_version=$(basename "$source_bin_dir")

    echo "--- Processing Project: ${project_name} (${source_dotnet_version}) ---"
    echo "Info: Found artifact bin directory: ${source_bin_dir}"
    echo "Info: Corresponding project root within artifacts: ${project_artifact_dir}"

    if [[ "$project_name" =~ \.[Tt]ests?$ || "$project_name" == *[Tt]est* ]]; then
        echo "Info: Skipping test project: ${project_name}"
        continue
    fi

    dest_root_in_temp="${TEMP_DIR}/${project_name}"
    dest_bin_dir_in_temp="${dest_root_in_temp}/bin/Release/${source_dotnet_version}"
    dest_obj_dir_in_temp="${dest_root_in_temp}/obj"

    bin_copied=false
    if [ -d "$source_bin_dir" ] && [ "$(ls -A "$source_bin_dir")" ]; then
        echo "Info: Preparing destination bin directory: ${dest_bin_dir_in_temp}"
        mkdir -p "$dest_bin_dir_in_temp"
        echo "Info: Copying bin artifacts from ${source_bin_dir} to ${dest_bin_dir_in_temp}"
        cp -aT "$source_bin_dir" "$dest_bin_dir_in_temp/" # Use -T for directory contents
        bin_copied=true
    else
        echo "Warning: Artifact bin directory '${source_bin_dir}' is empty or missing for project '${project_name}'. Skipping bin packaging for this TFM."
    fi

    obj_copied=false
    source_obj_dir="${project_artifact_dir}/obj"
    if [ -d "$source_obj_dir" ] && [ "$(ls -A "$source_obj_dir")" ]; then
        echo "Info: Found source obj directory within artifact structure: ${source_obj_dir}"
        echo "Info: Preparing destination obj directory in temp: ${dest_obj_dir_in_temp}"
        mkdir -p "$dest_obj_dir_in_temp"
        echo "Info: Copying contents of ${source_obj_dir} to ${dest_obj_dir_in_temp}"
        if cp -aT "$source_obj_dir" "$dest_obj_dir_in_temp/"; then # Use -T for directory contents
            obj_copied=true
        else
            echo "Error: Failed to copy obj directory from ${source_obj_dir} to ${dest_obj_dir_in_temp}"
            # Consider exiting if critical
        fi
    else
        echo "Info: Source obj directory '${source_obj_dir}' not found or empty within artifact structure. Skipping obj packaging."
    fi

    if [ "$bin_copied" = true ] || [ "$obj_copied" = true ]; then
        projects_packaged=$((projects_packaged + 1))
        echo "Info: Successfully packaged artifacts (bin and/or obj) for ${project_name} (${source_dotnet_version})."
    else
         echo "Warning: Neither bin artifacts nor obj directory were found/copied for ${project_name} (${source_dotnet_version}) from artifact structure."
    fi
    echo "--- Finished processing project: ${project_name} (${source_dotnet_version}) ---"
done < <(find "${SEARCH_ROOT}" -type d -path "${PATH_PATTERN}" -print0)

echo "Info: Total potential project artifact bin directories found matching pattern: ${total_projects_found_in_artifacts}"

if [ "$projects_packaged" -gt 0 ]; then
    echo "Info: Packaged artifacts (bin/obj) from ${projects_packaged} non-test project locations."
    echo "Info: Creating zip file: ${OUTPUT_ZIP}"
    if (cd "$TEMP_DIR" && zip -rq "${SCRIPT_START_DIR}/${OUTPUT_ZIP}" .); then
        echo "Success: Created zip file: ${SCRIPT_START_DIR}/${OUTPUT_ZIP}"
    else
        echo "Error: Failed to create zip file."
        exit 1
    fi
else
    echo "Warning: No artifacts (bin or obj) were packaged for any non-test projects."
    echo "Warning: Ensure projects built successfully in 'Release' for ${REPORTING_VERSION_TEXT}, producing output (including obj) in '${ARTIFACTS_ROOT_DIR:-${ARTIFACTS_ROOT_PATTERN}}'."
    echo "Warning: No zip file created."
    exit 0
fi

echo "Script finished."

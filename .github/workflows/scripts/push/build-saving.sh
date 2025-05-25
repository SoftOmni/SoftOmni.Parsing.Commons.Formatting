#!/bin/bash

# --- Configuration & Setup ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Optional: uncomment if you want to be stricter about unset variables
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
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
SCRIPT_START_DIR=$(pwd) # Remember where we started (primarily for placing the final zip)
projects_packaged=0
total_projects_found_in_artifacts=0

# --- Temporary Directory ---
TEMP_DIR=$(mktemp -d)
# Ensure temporary directory is cleaned up on script exit or interruption
trap 'EXIT_CODE=$?; echo "Info: Cleaning up temporary packaging directory: ${TEMP_DIR}"; rm -rf "${TEMP_DIR}"; exit $EXIT_CODE' EXIT HUP INT QUIT PIPE TERM
echo "Info: Created temporary directory for packaging: ${TEMP_DIR}"

# --- Mode Specific Setup ---
if [ "$MODE" == "all" ]; then
  ARTIFACTS_ROOT_PATTERN="build-artifacts-net*.*" # Pattern to find root dirs
  SEARCH_ROOT="." # Search from the current directory for the artifact roots
  # Path pattern to find the TFM-specific bin directories within any artifact root
  PATH_PATTERN="./${ARTIFACTS_ROOT_PATTERN}/*/bin/Release/net[0-9]*.[0-9]*"
  # Adjusted zip name slightly to reflect content
  OUTPUT_ZIP="release_bin_assets_files_all_versions.zip"
  REPORTING_VERSION_TEXT="all found versions"

  # Validate At Least One Artifacts Root Directory Exists
  if ! find . -maxdepth 1 -type d -name "${ARTIFACTS_ROOT_PATTERN}" -print -quit | grep -q .; then
    echo "Error: No artifact root directories matching '${ARTIFACTS_ROOT_PATTERN}' found in the current directory (${SCRIPT_START_DIR})."
    echo "Error: Please ensure artifacts have been downloaded or built correctly (containing bin and potentially obj)."
    exit 1
  fi
  echo "Info: Searching for artifacts across all roots matching: ${ARTIFACTS_ROOT_PATTERN}"

else # MODE == "single"
  # Argument Validation for Single Version Mode (keep expecting netX.Y format)
  dotnet_version_regex='^net[0-9]+\.[0-9]+$'
  if [[ ! "$DOTNET_VERSION_ARG" =~ $dotnet_version_regex ]]; then
    echo "Error: Please provide the target .NET version in netX.Y format (e.g., net8.0)."
    echo "Usage: $0 [<dotnet_version>]"
    echo "       (Omit <dotnet_version> to package all found versions)"
    exit 1
  fi

  DOTNET_VERSION="$DOTNET_VERSION_ARG"
  ARTIFACTS_ROOT_DIR="build-artifacts-${DOTNET_VERSION}"
  # Adjusted zip name slightly to reflect content
  OUTPUT_ZIP="release_bin_assets_files_${DOTNET_VERSION}.zip"
  REPORTING_VERSION_TEXT="target framework '${DOTNET_VERSION}'"
  SEARCH_ROOT="${ARTIFACTS_ROOT_DIR}" # Search within the specific artifact root
  # Path pattern relative to the specific artifact root dir
  PATH_PATTERN="*/bin/Release/${DOTNET_VERSION}"

  echo "Info: Target .NET Version: ${DOTNET_VERSION}"
  echo "Info: Searching for artifacts in root: ${ARTIFACTS_ROOT_DIR}"

  # Validate Specific Artifacts Root Directory
  if [ ! -d "${ARTIFACTS_ROOT_DIR}" ]; then
    echo "Error: Artifacts root directory '${ARTIFACTS_ROOT_DIR}' not found in (${SCRIPT_START_DIR})."
    echo "Error: Please ensure the artifacts have been downloaded or built correctly (containing bin and potentially obj)."
    exit 1
  fi
fi

echo "Info: Output Zip File: ${OUTPUT_ZIP}"
echo "Info: Searching for final artifact directories..."
echo "Info: Search Root: '${SEARCH_ROOT}'"
echo "Info: Path Pattern: '${PATH_PATTERN}'"

# --- Find and Process Artifact Directories ---
# Use process substitution to process each found bin directory
while IFS= read -r -d $'\0' source_bin_dir; do

    total_projects_found_in_artifacts=$((total_projects_found_in_artifacts + 1))

    # Extract the project name directory *within the artifact structure*
    # e.g., build-artifacts-net8.0/MyProject
    project_artifact_dir=$(dirname "$(dirname "$(dirname "$source_bin_dir")")")
    project_name=$(basename "$project_artifact_dir")

    # Extract the .NET version from the source bin directory path
    source_dotnet_version=$(basename "$source_bin_dir")

    echo "--- Processing Project: ${project_name} (${source_dotnet_version}) ---"
    echo "Info: Found artifact bin directory: ${source_bin_dir}"
    echo "Info: Corresponding project root within artifacts: ${project_artifact_dir}"

    # --- Filter out Test Projects ---
    if [[ "$project_name" =~ \.[Tt]ests?$ || "$project_name" == *[Tt]est* ]]; then
        echo "Info: Skipping test project: ${project_name}"
        continue # Skip to the next found directory
    fi

    # --- Define Destination Paths within TEMP_DIR ---
    # Structure: TEMP_DIR/ProjectName/bin/Release/netX.Y/*
    #            TEMP_DIR/ProjectName/obj/project.assets.json
    dest_root_in_temp="${TEMP_DIR}/${project_name}"
    dest_bin_dir="${dest_root_in_temp}/bin/Release/${source_dotnet_version}"
    dest_obj_dir="${dest_root_in_temp}/obj" # We still need the obj dir structure in temp

    # --- Package bin/Release Contents ---
    bin_copied=false
    if [ -d "$source_bin_dir" ] && [ "$(ls -A "$source_bin_dir")" ]; then
        echo "Info: Preparing destination bin directory: ${dest_bin_dir}"
        mkdir -p "$dest_bin_dir"

        echo "Info: Copying bin artifacts from ${source_bin_dir} to ${dest_bin_dir}"
        cp -a "$source_bin_dir/." "$dest_bin_dir/" # Set -e handles errors
        bin_copied=true
    else
        echo "Warning: Artifact bin directory '${source_bin_dir}' is empty or missing for project '${project_name}'. Skipping bin packaging for this TFM."
        # Continue to attempt packaging assets file
    fi

    # --- Package obj/project.assets.json (from ARTIFACT project root) ---
    assets_copied=false
    # Construct path to assets file *within the artifact structure*
    source_assets_file="${project_artifact_dir}/obj/project.assets.json"

    if [ -f "$source_assets_file" ]; then
        echo "Info: Found source assets file within artifact structure: ${source_assets_file}"

        # Ensure the destination obj directory exists in the temp structure
        echo "Info: Preparing destination obj directory for assets file: ${dest_obj_dir}"
        mkdir -p "$dest_obj_dir"

        echo "Info: Copying ${source_assets_file} to ${dest_obj_dir}"
        cp -a "$source_assets_file" "$dest_obj_dir/" # Set -e handles errors
        assets_copied=true
    else
        echo "Info: Source assets file '${source_assets_file}' not found within artifact structure. Skipping asset file packaging."
        # This is not necessarily an error, pack might still work if dependencies are simple or already resolved
    fi

    # --- Increment Packaged Count ---
    # Count the project if we successfully copied EITHER bin artifacts OR the assets file
    if [ "$bin_copied" = true ] || [ "$assets_copied" = true ]; then
        projects_packaged=$((projects_packaged + 1))
        echo "Info: Successfully packaged artifacts (bin and/or assets) for ${project_name} (${source_dotnet_version})."
    else
         echo "Warning: Neither bin artifacts nor project.assets.json were found/copied for ${project_name} (${source_dotnet_version}) from artifact structure."
    fi

    echo "--- Finished processing project: ${project_name} (${source_dotnet_version}) ---"

# Find command adjusted slightly: using -path requires full pattern match including ./
done < <(find "${SEARCH_ROOT}" -type d -path "${PATH_PATTERN}" -print0)


echo "Info: Total potential project artifact bin directories found matching pattern: ${total_projects_found_in_artifacts}"

# --- Create Zip File ---
if [ "$projects_packaged" -gt 0 ]; then
    echo "Info: Packaged artifacts (bin/assets) from ${projects_packaged} non-test project locations."
    echo "Info: Creating zip file: ${OUTPUT_ZIP}"
    # Zip contents of TEMP_DIR, preserving the structure
    if (cd "$TEMP_DIR" && zip -rq "${SCRIPT_START_DIR}/${OUTPUT_ZIP}" .); then
        echo "Success: Created zip file: ${SCRIPT_START_DIR}/${OUTPUT_ZIP}"
    else
        echo "Error: Failed to create zip file."
        exit 1
    fi
else
    echo "Warning: No artifacts (bin or obj/project.assets.json) were packaged for any non-test projects from the artifact structure."
    echo "Warning: Ensure the relevant projects have been built successfully in 'Release' configuration for ${REPORTING_VERSION_TEXT}, producing output (including obj/project.assets.json) in '${ARTIFACTS_ROOT_DIR:-${ARTIFACTS_ROOT_PATTERN}}'."
    echo "Warning: No zip file created."
    # Exit with success code 0 as no error occurred, just nothing to package
    exit 0
fi

# Cleanup is handled by the trap EXIT handler
echo "Script finished."
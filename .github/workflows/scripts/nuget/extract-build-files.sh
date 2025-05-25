#!/bin/bash

# --- Configuration & Setup ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# set -u # Optional: uncomment if you want to be stricter about unset variables
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -o pipefail

# --- Variables ---
# Adjust archive name pattern if needed, this matches both single and all
ARCHIVE_PATTERN="release_bin_assets_files_all_versions.zip"
WORKSPACE_DIR=$(pwd) # Should be the root of the checkout

echo "Info: Starting build artifact extraction process."
echo "Info: Working directory: ${WORKSPACE_DIR}"

# --- Find the Archive ---
# Use find to get the specific archive name (handles both single and all modes)
ARCHIVE_NAME=$(find . -maxdepth 1 -name "${ARCHIVE_PATTERN}" -print -quit)

if [ -z "$ARCHIVE_NAME" ]; then
  echo "Error: Build data archive matching '${ARCHIVE_PATTERN}' not found in the current directory (${WORKSPACE_DIR})."
  echo "Error: Ensure the 'Download build data' step succeeded and provided the correct zip file."
  exit 1
fi
# Strip leading ./ if find added it
ARCHIVE_NAME=${ARCHIVE_NAME#./}
echo "Info: Found build data archive: ${ARCHIVE_NAME}"


# --- Temporary Directory ---
TEMP_DIR=$(mktemp -d)
# Ensure temporary directory is cleaned up on script exit or interruption
trap 'EXIT_CODE=$?; echo "Info: Cleaning up temporary extraction directory: ${TEMP_DIR}"; rm -rf "${TEMP_DIR}"; exit $EXIT_CODE' EXIT HUP INT QUIT PIPE TERM
echo "Info: Created temporary directory for extraction: ${TEMP_DIR}"

# --- Extract Archive ---
echo "Info: Extracting '${ARCHIVE_NAME}' to '${TEMP_DIR}'..."
if ! unzip -q "${ARCHIVE_NAME}" -d "${TEMP_DIR}"; then
    echo "Error: Failed to extract '${ARCHIVE_NAME}'."
    exit 1 # Trap will handle cleanup
fi
echo "Info: Archive extracted successfully."
echo "Info: Contents of extraction directory:"
ls -lR "${TEMP_DIR}" # Use -R to show structure

# --- Process Extracted Projects ---
# Find all top-level directories within the temporary extraction folder (Project Names).
find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' extracted_proj_root_in_temp; do

    project_name=$(basename "$extracted_proj_root_in_temp")
    echo "--- Processing project: ${project_name} ---"

    # --- Locate Source Project Directory ---
    source_proj_dir="${WORKSPACE_DIR}/${project_name}"
    if [ ! -d "${source_proj_dir}" ]; then
        echo "Warning: Source directory '${source_proj_dir}' for project '${project_name}' not found in workspace. Skipping placement."
        continue # Skip to the next project
    fi
    echo "Info: Found source project directory: ${source_proj_dir}"

    # --- Place obj Directory Contents ---
    temp_obj_dir="${extracted_proj_root_in_temp}/obj"
    dest_obj_dir="${source_proj_dir}/obj"

    if [ -d "$temp_obj_dir" ]; then
        echo "Info: Found extracted obj directory: ${temp_obj_dir}"
        if [ "$(ls -A "$temp_obj_dir")" ]; then
            echo "Info: Preparing destination obj directory: ${dest_obj_dir}"
            mkdir -p "$dest_obj_dir"

            echo "Info: Copying obj artifacts from '${temp_obj_dir}' to '${dest_obj_dir}'"
            if ! cp -a "${temp_obj_dir}/." "${dest_obj_dir}/"; then
                 echo "Error: Failed to copy obj artifacts for project '${project_name}'."
                 exit 1 # Let trap handle cleanup
            fi
            echo "Info: Successfully copied obj artifacts for '${project_name}'."
        else
             echo "Info: Extracted obj directory '${temp_obj_dir}' is empty. Skipping obj placement."
        fi
    else
        echo "Info: No extracted obj directory found at '${temp_obj_dir}'. Skipping obj placement."
    fi

    # --- Place bin/Release/netX.Y Directory Contents ---
    temp_bin_release_base="${extracted_proj_root_in_temp}/bin/Release"

    if [ -d "$temp_bin_release_base" ]; then
        echo "Info: Found extracted bin/Release base: ${temp_bin_release_base}"
        # Find all TFM directories within the extracted bin/Release
        find "${temp_bin_release_base}" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' temp_bin_tfm_dir; do
            tfm=$(basename "$temp_bin_tfm_dir")
            dest_bin_tfm_dir="${source_proj_dir}/bin/Release/${tfm}"

            echo "Info: Processing extracted TFM directory: ${temp_bin_tfm_dir}"
            if [ "$(ls -A "$temp_bin_tfm_dir")" ]; then
                echo "Info: Preparing destination bin directory for TFM '${tfm}': ${dest_bin_tfm_dir}"
                mkdir -p "$dest_bin_tfm_dir"

                echo "Info: Copying bin artifacts from '${temp_bin_tfm_dir}' to '${dest_bin_tfm_dir}'"
                if ! cp -a "${temp_bin_tfm_dir}/." "${dest_bin_tfm_dir}/"; then
                    echo "Error: Failed to copy bin artifacts for project '${project_name}' TFM '${tfm}'."
                    exit 1 # Let trap handle cleanup
                fi
                echo "Info: Successfully copied bin artifacts for TFM '${tfm}'."
            else
                echo "Info: Extracted TFM directory '${temp_bin_tfm_dir}' is empty. Skipping placement for this TFM."
            fi
        done
    else
        echo "Info: No extracted bin/Release directory found at '${temp_bin_release_base}'. Skipping bin placement."
    fi

    echo "--- Finished processing project: ${project_name} ---"

done

# Cleanup is handled by the trap EXIT handler
echo "Info: Build artifact extraction and placement completed successfully."
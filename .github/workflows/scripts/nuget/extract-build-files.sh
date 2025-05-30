#!/bin/bash

# .github/workflows/scripts/nuget/extract-build-files.sh

# --- Configuration & Setup ---
set -e
set -o pipefail

# --- Variables ---
ARCHIVE_PATTERN="release_bin_assets_files_all_versions.zip" # Ensure this matches the name in build-saving.sh
WORKSPACE_DIR=$(pwd) # Should be the root of the checkout

echo "Info: Starting build artifact extraction process."
echo "Info: Working directory: ${WORKSPACE_DIR}"

# --- Find the Archive ---
ARCHIVE_NAME=$(find . -maxdepth 1 -name "${ARCHIVE_PATTERN}" -print -quit)
if [ -z "$ARCHIVE_NAME" ]; then
  echo "Error: Build data archive matching '${ARCHIVE_PATTERN}' not found in ${WORKSPACE_DIR}."
  exit 1
fi
ARCHIVE_NAME=${ARCHIVE_NAME#./}
echo "Info: Found build data archive: ${ARCHIVE_NAME}"

# --- Temporary Directory for Extraction ---
TEMP_EXTRACT_DIR=$(mktemp -d)
trap 'EXIT_CODE=$?; echo "Info: Cleaning up temporary extraction directory: ${TEMP_EXTRACT_DIR}"; rm -rf "${TEMP_EXTRACT_DIR}"; exit $EXIT_CODE' EXIT HUP INT QUIT PIPE TERM
echo "Info: Created temporary directory for extraction: ${TEMP_EXTRACT_DIR}"

# --- Extract Archive ---
echo "Info: Extracting '${ARCHIVE_NAME}' to '${TEMP_EXTRACT_DIR}'..."
if ! unzip -q "${ARCHIVE_NAME}" -d "${TEMP_EXTRACT_DIR}"; then
    echo "Error: Failed to extract '${ARCHIVE_NAME}'."
    exit 1
fi
echo "Info: Archive extracted successfully."
echo "Info: Contents of extraction directory:"
if command -v tree &> /dev/null; then tree -L 2 "${TEMP_EXTRACT_DIR}"; else ls -lR "${TEMP_EXTRACT_DIR}"; fi


# --- Process Extracted Projects ---
# Iterate over project names found as top-level directories in the extracted zip content
find "${TEMP_EXTRACT_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' extracted_proj_content_root; do

    project_name_from_zip=$(basename "$extracted_proj_content_root")
    echo "--- Processing project from zip: ${project_name_from_zip} ---"

    # --- Locate Actual Source Project Directory in Workspace ---
    # This attempts to find a directory named project_name_from_zip anywhere in the workspace.
    # This assumes project directory names (the part that was zipped) are unique enough.
    mapfile -t candidate_project_dirs < <(find "${WORKSPACE_DIR}" -type d -name "${project_name_from_zip}" -print)
    actual_project_dir_in_workspace=""

    if [ ${#candidate_project_dirs[@]} -eq 0 ]; then
        echo "Warning: No directory named '${project_name_from_zip}' found in workspace '${WORKSPACE_DIR}'. Skipping placement."
        continue
    elif [ ${#candidate_project_dirs[@]} -gt 1 ]; then
        echo "Warning: Multiple directories named '${project_name_from_zip}' found in workspace. Using the first one: ${candidate_project_dirs[0]}"
        # For more robustness, you might want to refine this (e.g., check for a .csproj file inside)
        # Or, if ambiguity is critical, log an error and skip/exit.
        # Example: If one is 'src/ProjectA' and another is 'tests/ProjectA', this needs care.
        # For now, we proceed with the first match.
        actual_project_dir_in_workspace="${candidate_project_dirs[0]}"
    else
        actual_project_dir_in_workspace="${candidate_project_dirs[0]}"
    fi
    echo "Info: Matched zip entry '${project_name_from_zip}' to workspace project directory: '${actual_project_dir_in_workspace}'"

    # --- Place obj Directory Contents ---
    temp_obj_dir_path="${extracted_proj_content_root}/obj"
    dest_obj_dir_path="${actual_project_dir_in_workspace}/obj"

    if [ -d "$temp_obj_dir_path" ]; then
        echo "Info: Found extracted obj directory: ${temp_obj_dir_path}"
        if [ "$(ls -A "$temp_obj_dir_path")" ]; then
            echo "Info: Preparing destination obj directory: ${dest_obj_dir_path}"
            mkdir -p "$dest_obj_dir_path"
            echo "Info: Copying obj artifacts from '${temp_obj_dir_path}/' to '${dest_obj_dir_path}/'"
            # Using rsync for better directory content copying and cleanup of stale files at destination
            if rsync -a --delete "${temp_obj_dir_path}/" "${dest_obj_dir_path}/"; then
                 echo "Info: Successfully copied obj artifacts for '${project_name_from_zip}'."
            else
                 echo "Error: rsync failed to copy obj artifacts for project '${project_name_from_zip}'. Trying cp."
                 if cp -aT "${temp_obj_dir_path}" "${dest_obj_dir_path}/"; then # -T copies contents
                    echo "Info: Successfully copied obj artifacts using cp for '${project_name_from_zip}'."
                 else
                    echo "Error: cp also failed to copy obj artifacts for project '${project_name_from_zip}'."
                    exit 1
                 fi
            fi
        else
             echo "Info: Extracted obj directory '${temp_obj_dir_path}' is empty. Skipping obj placement."
        fi
    else
        echo "Info: No extracted obj directory found at '${temp_obj_dir_path}'. Skipping obj placement for ${project_name_from_zip}."
    fi

    # --- Place bin/Release/netX.Y Directory Contents ---
    temp_bin_release_base_path="${extracted_proj_content_root}/bin/Release"
    if [ -d "$temp_bin_release_base_path" ]; then
        echo "Info: Found extracted bin/Release base: ${temp_bin_release_base_path} for ${project_name_from_zip}"
        # Iterate over TFM directories like net6.0, net7.0 etc.
        find "${temp_bin_release_base_path}" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' temp_bin_tfm_dir_path; do
            tfm_name=$(basename "$temp_bin_tfm_dir_path")
            dest_bin_tfm_dir_path="${actual_project_dir_in_workspace}/bin/Release/${tfm_name}"

            echo "Info: Processing extracted TFM directory: ${temp_bin_tfm_dir_path}"
            if [ "$(ls -A "$temp_bin_tfm_dir_path")" ]; then
                echo "Info: Preparing destination bin directory for TFM '${tfm_name}': ${dest_bin_tfm_dir_path}"
                mkdir -p "$dest_bin_tfm_dir_path"
                echo "Info: Copying bin artifacts from '${temp_bin_tfm_dir_path}/' to '${dest_bin_tfm_dir_path}/'"
                if rsync -a --delete "${temp_bin_tfm_dir_path}/" "${dest_bin_tfm_dir_path}/"; then
                    echo "Info: Successfully copied bin artifacts for TFM '${tfm_name}'."
                else
                    echo "Error: rsync failed to copy bin artifacts for TFM '${tfm_name}'. Trying cp."
                    if cp -aT "${temp_bin_tfm_dir_path}" "${dest_bin_tfm_dir_path}/"; then # -T copies contents
                        echo "Info: Successfully copied bin artifacts using cp for TFM '${tfm_name}'."
                    else
                        echo "Error: cp also failed to copy bin artifacts for TFM '${tfm_name}'."
                        exit 1
                    fi
                fi
            else
                echo "Info: Extracted TFM directory '${temp_bin_tfm_dir_path}' is empty. Skipping placement for this TFM."
            fi
        done
    else
        echo "Info: No extracted bin/Release directory found at '${temp_bin_release_base_path}'. Skipping bin placement for ${project_name_from_zip}."
    fi
    echo "--- Finished processing project: ${project_name_from_zip} ---"
done

echo "Info: Build artifact extraction and placement completed successfully."

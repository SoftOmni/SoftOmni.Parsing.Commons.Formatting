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
echo "Info: Basename of WORKSPACE_DIR: $(basename "${WORKSPACE_DIR}")"


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
    # Find all directories matching the project name.
    # We use -print0 and mapfile for safer handling of names with spaces/newlines.
    mapfile -t candidate_project_dirs < <(find "${WORKSPACE_DIR}" -type d -name "${project_name_from_zip}" -print0 | xargs -0 printf "%s\n")
    actual_project_dir_in_workspace=""

    if [ ${#candidate_project_dirs[@]} -eq 0 ]; then
        echo "Warning: No directory named '${project_name_from_zip}' found in workspace '${WORKSPACE_DIR}'. Skipping placement."
        continue
    elif [ ${#candidate_project_dirs[@]} -eq 1 ]; then
        # Only one match, use it.
        actual_project_dir_in_workspace="${candidate_project_dirs[0]}"
        echo "Info: Found unique project directory: '${actual_project_dir_in_workspace}'"
    else
        # Multiple matches. We need to be more selective.
        # Prioritize paths that are NOT the WORKSPACE_DIR itself, if others exist.
        # Also, prioritize paths that directly contain a .csproj file matching (or related to) the project name.
        echo "Warning: Multiple directories named '${project_name_from_zip}' found. Attempting to select the best match:"
        printf "  %s\n" "${candidate_project_dirs[@]}"

        best_match=""
        highest_score=-1

        for candidate_dir in "${candidate_project_dirs[@]}"; do
            current_score=0
            # Prefer deeper paths (higher score for more path components relative to WORKSPACE_DIR)
            relative_path=${candidate_dir#${WORKSPACE_DIR}/}
            # Count slashes in relative path to estimate depth
            depth=$(echo "$relative_path" | tr -cd '/' | wc -c)
            current_score=$((current_score + depth * 10)) # Weight depth

            # Check if it contains a .csproj file
            # Try to match csproj name with directory name first
            if [ -f "${candidate_dir}/${project_name_from_zip}.csproj" ]; then
                current_score=$((current_score + 100)) # Strong indicator
            elif compgen -G "${candidate_dir}/*.csproj" > /dev/null; then
                 # If any csproj exists, give some points
                current_score=$((current_score + 20))
            fi

            # Avoid selecting WORKSPACE_DIR itself if other deeper/better options exist
            # unless it's the only option or has a strong .csproj match
            if [ "$candidate_dir" == "$WORKSPACE_DIR" ]; then
                # If it's the workspace root, only give it a high score if a matching csproj is directly there
                if [ ! -f "${candidate_dir}/${project_name_from_zip}.csproj" ] && \
                   ! compgen -G "${candidate_dir}/*.csproj" > /dev/null; then
                    current_score=$((current_score - 50)) # Penalize if it's root without a clear project file
                fi
            fi

            echo "  - Candidate: '$candidate_dir', Depth: $depth, Score: $current_score"

            if [ "$current_score" -gt "$highest_score" ]; then
                highest_score=$current_score
                best_match="$candidate_dir"
            fi
        done

        if [ -n "$best_match" ]; then
            actual_project_dir_in_workspace="$best_match"
            echo "Info: Selected best match from multiple candidates: '${actual_project_dir_in_workspace}' (Score: $highest_score)"
        else
            echo "Error: Could not determine a suitable project directory among multiple candidates for '${project_name_from_zip}'. Skipping."
            continue
        fi
    fi

    # --- Final Check: If selected path is WORKSPACE_DIR, ensure it's justified ---
    # This is a safety net if the scoring above still picked WORKSPACE_DIR ambiguously.
    # This logic can be complex; the primary defense is good scoring above.
    if [ "$actual_project_dir_in_workspace" == "$WORKSPACE_DIR" ]; then
        # If the project name from zip is different from the repo name (basename of WORKSPACE_DIR),
        # it's highly unlikely artifacts for "ProjectA" should go into the root of "RepoB".
        # This situation implies an error in how project_name_from_zip was derived or matched.
        if [ "$(basename "${WORKSPACE_DIR}")" != "$project_name_from_zip" ]; then
             # And if WORKSPACE_DIR does not contain a .csproj for project_name_from_zip
             if [ ! -f "${WORKSPACE_DIR}/${project_name_from_zip}.csproj" ]; then
                echo "Error: Ambiguity. Project '${project_name_from_zip}' resolved to WORKSPACE_DIR ('${WORKSPACE_DIR}') but seems incorrect (names differ and no direct csproj match). Skipping."
                continue
             fi
        fi
        echo "Info: Project '${project_name_from_zip}' will be placed at WORKSPACE_DIR root. This is assumed to be a root-level project."
    fi


    # --- Place obj Directory Contents ---
    temp_obj_dir_path="${extracted_proj_content_root}/obj"
    dest_obj_dir_path="${actual_project_dir_in_workspace}/obj"

    if [ -d "$temp_obj_dir_path" ]; then
        echo "Info: Found extracted obj directory: ${temp_obj_dir_path}"
        if [ "$(ls -A "$temp_obj_dir_path")" ]; then
            echo "Info: Preparing destination obj directory: ${dest_obj_dir_path}"
            mkdir -p "$dest_obj_dir_path"
            echo "Info: Copying obj artifacts from '${temp_obj_dir_path}/' to '${dest_obj_dir_path}/'"
            if rsync -a --delete "${temp_obj_dir_path}/" "${dest_obj_dir_path}/"; then
                 echo "Info: Successfully copied obj artifacts for '${project_name_from_zip}'."
            elif cp -aT "${temp_obj_dir_path}" "${dest_obj_dir_path}/"; then
                echo "Info: Successfully copied obj artifacts using cp for '${project_name_from_zip}'."
            else
                echo "Error: cp also failed to copy obj artifacts for project '${project_name_from_zip}'."
                exit 1
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
                elif cp -aT "${temp_bin_tfm_dir_path}" "${dest_bin_tfm_dir_path}/"; then
                    echo "Info: Successfully copied bin artifacts using cp for TFM '${tfm_name}'."
                else
                    echo "Error: cp also failed to copy bin artifacts for TFM '${tfm_name}'."
                    exit 1
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
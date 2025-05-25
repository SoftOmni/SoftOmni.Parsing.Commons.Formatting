#!/bin/bash

location_simple="${2}/test_results"
location="${location_simple}/${1}"

function create_directory()
{
  if [ ! -d "${1}" ]; then
    echo "Creating directory ${1}"
    mkdir "${1}"
    if [ -d "${1}" ]; then
      echo "Created directory ${1}"
    else
      echo "Failed to create directory ${1} for some reasons. Check logs right above me."
      exit 1
    fi
  else
    echo "Directory ${1} already exists!"
  fi
}

create_directory "${location_simple}"
create_directory "${location}"

exit 0


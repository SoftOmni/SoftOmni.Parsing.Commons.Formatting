#!/bin/bash

# check that we have a single argument
if [ "$#" -ne 1 ]; then
  if [ "$#" -eq 0 ]; then
    echo "ERROR: expected the path to the test project but no arguments were provided."
  else
    echo "ERROR: expected one argument (a path to a test project) but $# were provided."
  fi
  
  exit 2
fi

# check that the argument points to a valid file
if [ ! -f "$1" ]; then
  echo "The dotnet project \"$1\" does not exist!"
  exit 1
fi

# extract the parent directory of the provided file path
PARENT_DIRECTORY=$(dirname "$1")
echo "Parent directory: $PARENT_DIRECTORY"

echo "PARENT_DIRECTORY=$PARENT_DIRECTORY" >> "$GITHUB_ENV"

# extract the current directory for later
PROJECT_DIRECTORY=$(pwd)
echo "Project directory: \"$PROJECT_DIRECTORY\""

echo "PROJECT_DIRECTORY=$PROJECT_DIRECTORY" >> "$GITHUB_ENV"

#!/bin/bash

cd "${0%/*}/.."

case "${0##*/}" in
    CreateProject.sh)
        if [ "$#" -eq 0 ]; then
            directive=LIST
        else
            directive=CREATE
        fi
        ;;
    LaunchWorkflow.sh)
        directive=WORKFLOW ;;
    LaunchSimulation.sh)
        directive=SIMULATE ;;
esac

echo "Hog [Warning]: $0 is obsolete, you should use ./Hog/Do $directive now!"
exec ./Hog/Do $directive "$@"

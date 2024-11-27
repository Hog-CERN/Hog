#!/bin/bash

# Default API URL
DEFAULT_GITLAB_API="https://gitlab.com/api/v4"
API_URL=$DEFAULT_GITLAB_API

# Parse arguments
while getopts "a:" opt; do
  case ${opt} in
    a )
      API_URL=$OPTARG
      ;;
    \? )
      echo "Usage: RemoveBadges.sh [-a api_url]"
      exit 1
      ;;
  esac
done

# Replace these with your own values
TOKEN=$1
PROJECT_ID=$2

while true; do
  # Get all badges
  BADGES=$(curl --header "PRIVATE-TOKEN: $TOKEN" "$API_URL/projects/$PROJECT_ID/badges" | jq -r '.[].id')

  # Break the loop if no badges found
  if [ -z "$BADGES" ]; then
    echo "No more badges to remove."
    break
  fi

  # Remove each badge
  for BADGE_ID in $BADGES; do
    curl --request DELETE --header "PRIVATE-TOKEN: $TOKEN" "$API_URL/projects/$PROJECT_ID/badges/$BADGE_ID"
    echo "Removed badge with ID: $BADGE_ID"
  done
done

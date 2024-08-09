#!/bin/bash

# Function to update the version number
update_version() {
  echo "Do you want to update the version? (1 for Yes, 2 for No)"
  read update_version_choice

  if [ "$update_version_choice" -eq 1 ]; then
    echo "Select the version type to update: (1 for Major, 2 for Minor, 3 for Patch)"
    read version_type

    # Extract current version
    current_version=$(grep -oP '(?<=## \[v)[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | head -1)

    IFS='.' read -r major minor patch <<<"$current_version"

    case $version_type in
    1)
      ((major++))
      minor=0
      patch=0
      ;;
    2)
      ((minor++))
      patch=0
      ;;
    3)
      ((patch++))
      ;;
    *)
      echo "Invalid choice!"
      exit 1
      ;;
    esac

    new_version="v$major.$minor.$patch"
    echo "Updated version to $new_version"

    # Update the placeholders in CHANGELOG.md
    sed -i "s/\$(latest revision)/$new_version/g" CHANGELOG.md
    sed -i "s/\$(today's date)/$(date +%Y-%m-%d)/g" CHANGELOG.md

  else
    new_version=$(grep -oP '(?<=## \[v)[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | head -1)
    echo "Keeping current version: $new_version"
  fi
}

# Function to update changelog content
update_changelog() {
  echo "What section do you want to update?"
  echo "1 - Unreleased"
  echo "2 - Added"
  echo "3 - Changed"
  echo "4 - Deprecated"
  echo "5 - Removed"
  echo "6 - Fixed"
  echo "7 - Security"
  read section_choice

  case $section_choice in
  1) section="Unreleased" ;;
  2) section="Added" ;;
  3) section="Changed" ;;
  4) section="Deprecated" ;;
  5) section="Removed" ;;
  6) section="Fixed" ;;
  7) section="Security" ;;
  *)
    echo "Invalid choice!"
    exit 1
    ;;
  esac

  date=$(date +%Y-%m-%d)
  echo "Date: $date"

  echo "Enter a concise summary of the change:"
  read summary

  echo "Enter the Git commit ID:"
  read commit_id

  echo "Enter your name:"
  read user_name

  # Prepare the changelog entry
  changelog_entry="\n- $summary\n- Revision: $new_version\n- Date: $date\n- Commit ID: $commit_id\n- User: $user_name\n"

  # Insert the changelog entry under the relevant section
  awk -v section="## [$section]" -v entry="$changelog_entry" '
  $0 ~ section {
    print $0 "\n" entry
    next
  }
  { print }
  ' CHANGELOG.md > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md

  echo "Changelog updated successfully!"
}

# Main script execution
update_version
update_changelog


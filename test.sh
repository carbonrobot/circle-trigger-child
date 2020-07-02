#! /bin/bash -e

function check_delete {
  while read -r branch; do
    echo "Found $branch"
  done
  # count=$(git rev-list --count "$branch" ^HEAD)
  # if [ "$count" -eq 1 ]; then
  #   echo "Deleting $branch"
  #   # git push origin -d "$branch"
  # else 
  #   echo "Branch has extraneous commits. Ignoring."
  # fi
}

git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/rbibot/rbilabs" | check_delete

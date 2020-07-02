#! /bin/bash -e

# env secrets
CIRCLE_PROJECT_REPONAME=circle-trigger-child
CIRCLE_PROJECT_USERNAME=carbonrobot

# configuration
reponame=${CIRCLE_PROJECT_REPONAME}
orgname=${CIRCLE_PROJECT_USERNAME}
gh_user=${GH_USER}
gh_auth_token=${GH_AUTH_TOKEN}
version=$1

# prefix for all pull requests so we can manage
# prs created by this script without affecting anyone else
prefix="rbibot/rbilabs"
git config --global user.email circleci@circleci
git config --global user.name CircleCI

if [ -z "$version" ]; then
  echo "Version required as first positional param. Exiting!"
  exit 1
fi

# update the packages and bail if the script is missing or fails
echo "Update @rbilabs packages to latest"
yarn update-packages || {
  echo "Error updating packages"
  exit 1
}

# Create a new branch and attempt a commit
# If the commit fails for no changes, exit
echo "Creating new branch $prefix/$version"
git checkout -b "$prefix/$version"
git commit -a -m "Bumps @rbilabs to $version" || {
  echo "No changes found. Up to date."
  exit 0
}

# Clean up old branches that are now out of date
# Github will automatically close the PR when the remote branch is deleted
echo "Removing older branches"

function check_delete {
  read -r branch
  echo "Found $branch"
  count=$(git rev-list --count "$branch" ^HEAD)
  if [ "$count" -eq 1 ]; then
    echo "Deleting $branch"
    git push origin -d "$branch"
  else 
    echo "Branch has extraneous commits. Ignoring."
  fi
}

branch=$(git for-each-ref --format='%(refname:short)' "refs/remotes/origin/$prefix" | head -1)
if [ -z "$branch" ]; then 
  echo "No out of date branches found"
else
  echo "Out of date branch(es) found"
  git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/$prefix" | check_delete
fi

# Create a pull request for the changes
echo "Creating pull request for $prefix/$version"
git push -u origin "$prefix/$version"
pull_request_data=$(cat << EOF
{
  "base": "master",
  "head": "$prefix/$version",
  "title": "Bumps @rbilabs to $version", 
  "body": ":rocket: Bumps @rbilabs to $version\n\n:robot: will automatically manage this PR as long as you don't alter it yourself\n\n- This PR will be deleted if a newer version is released\n\n- This PR will be automatically merged if CI checks are complete.\n\nSee package changes at https://github.com/rbilabs/ctg-packages/releases/tag/v$version"
}
EOF
)

response=$(curl -s -u "$gh_user":"$gh_auth_token" -X POST -d "$pull_request_data" "https://api.github.com/repos/$orgname/$reponame/pulls")
pull_request_url=$(echo $response | jq -r .html_url)

# When the pull request api fails, it returns a null string value
if [ "$pull_request_url" == "null" ]; then
  echo "Unable to generate pull request"
  echo "$response"
  exit 1
fi

echo "Pull request $pull_request_url"

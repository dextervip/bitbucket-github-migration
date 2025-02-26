#!/bin/bash

# Exit on error
set -e

# GitHub organization or username where repositories will be created
echo -n "Enter GitHub organization name: "
read GITHUB_ORG

# Validate input
if [ -z "$GITHUB_ORG" ]; then
    echo "Error: GitHub organization name cannot be empty"
    exit 1
fi

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Please authenticate with GitHub first using: gh auth login"
    exit 1
fi

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    # Clean up BFG jar if it exists
    if [ -f "bfg.jar" ]; then
        rm bfg.jar
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Download BFG jar if not present
if [ ! -f "bfg.jar" ]; then
    echo "Downloading BFG..."
    curl -L -o bfg.jar https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
fi

# Store absolute path to BFG jar
BFG_JAR="$(pwd)/bfg.jar"

# List of Bitbucket repositories to migrate
# REPOS=(
#     "git@bitbucket.org:econciliador/econciliador.git"
# )
source urls.sh

# Add this function before the main loop
is_branch_old() {
    local branch=$1
    # Get the timestamp of the latest commit in the branch
    local last_commit_timestamp=$(git log -1 --format=%ct "$branch" 2>/dev/null)
    local current_timestamp=$(date +%s)
    local one_year_ago=$((current_timestamp - 15768000))  # 182.5 days in seconds
    
    # Return 0 (true) if branch is old, 1 (false) if recent
    [ "$last_commit_timestamp" -lt "$one_year_ago" ]
}

for repo_url in "${REPOS[@]}"; do
    # Extract namespace and repo name from URL
    NAMESPACE=$(echo $repo_url | cut -d':' -f2 | cut -d'/' -f1)
    REPO_NAME=$(echo $repo_url | cut -d'/' -f2 | sed 's/\.git$//')
    
    echo "Migrating $NAMESPACE/$REPO_NAME..."
    
    # Create temp directory for cloning
    TEMP_DIR=$(mktemp -d) || { echo "Failed to create temp directory"; exit 1; }
    cd "$TEMP_DIR" || { echo "Failed to enter temp directory"; exit 1; }
    
    # Clone repository with all branches
    git clone --mirror --progress "$repo_url" || { echo "Failed to clone $repo_url"; exit 1; }
    cd "${REPO_NAME}.git" || { echo "Failed to enter repository directory"; exit 1; }
    
    # Delete old inactive branches before cleaning
    echo "Checking for old inactive branches..."
    git for-each-ref --format='%(refname:short)' refs/heads/ | while read branch; do
        # Skip master and main branches
        if [[ "$branch" != "master" && "$branch" != "main" ]]; then
            if is_branch_old "$branch"; then
                echo "Deleting old branch: $branch"
                git branch -D "$branch"
            fi
        fi
    done
    
    # Clean large files using BFG
    echo "Cleaning repository using BFG..."
    java -jar "$BFG_JAR" --strip-blobs-bigger-than 40M .
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
    
    # Create new repository URL for GitHub
    GITHUB_URL="git@github.com:${GITHUB_ORG}/${REPO_NAME}.git"
    
    # Create repository on GitHub if it doesn't exist
    echo "Creating repository on GitHub if it doesn't exist..."
    gh repo create "${GITHUB_ORG}/${REPO_NAME}" --private --source=. --remote=github || {
        # If repo exists, just set the remote
        git remote add github "$GITHUB_URL" || { echo "Failed to add GitHub remote"; exit 1; }
    }
    
    # Push all branches and tags
    git push --progress github --mirror || { echo "Failed to push to GitHub"; exit 1; }
    # sleep for few a seconds
    sleep 5
    # Set default branch to master
    echo "Setting default branch to master..."
    gh repo edit "${GITHUB_ORG}/${REPO_NAME}" --default-branch master
    
    cd ../..
    echo "Successfully migrated $REPO_NAME to GitHub"
    sleep 5
done

echo "Migration completed!"

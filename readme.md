# Bitbucket Cloud to GitHub Migration

This project provides scripts to migrate repositories from Bitbucket Cloud to GitHub. This script only migrates the repository contents and does not migrate issues, pull requests, or wiki pages.

## Overview

The migration is performed in two steps:
1. **List Repositories:**  
   The Python script (`list_repositories.py`) fetches repositories from Bitbucket using your credentials and saves the Git clone URLs in a bash script (`urls.sh`).
2. **Repository Migration:**  
   The Bash script (`migrate.sh`) reads the list of repositories from `urls.sh`, clones them, cleans up old branches and large files, and pushes them to GitHub.

## Dependencies

- **Python 3** and the `requests` package  
  Install with: `pip install requests`
- **GitHub CLI (gh)**  
  Follow instructions at: https://cli.github.com/
- **BFG Repo-Cleaner**  
  The script downloads BFG automatically; ensure Java is installed.

## Usage

1. **Prepare Bitbucket Credentials:**
   - Run the `list_repositories.py` script:
     ```
     python list_repositories.py
     ```
   - Enter your Bitbucket username, app password, and workspace.
   - This will generate a file named `urls.sh` with the repository URLs.

2. **Migrate Repositories:**
   - Ensure that you are authenticated with GitHub CLI:
     ```
     gh auth login
     ```
   - Run the migration script:
     ```
     bash migrate.sh
     ```
   - The script will:
     - Clone each Bitbucket repository.
     - Remove branches with no recent activity (except `main` and `master`).
     - Clean large files using BFG.
     - Create new repositories on GitHub and push the contents.

## Notes

- The script sets the default branch to `master` on GitHub.
- Use caution when deleting branches; ensure backups or clones exist if needed.


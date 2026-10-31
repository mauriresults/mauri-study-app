#!/usr/bin/env bash
# Creates a completely NEW GitHub repository; never modifies MauriResults repositories.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gh >/dev/null || { echo 'Install GitHub CLI (gh) first.' >&2; exit 1; }
gh auth status
if [[ -e .git ]]; then echo 'Repository already initialized; refusing to replace it' >&2; exit 1; fi
git init -b main
git add .
git commit -m 'Initial independent Mauri Study Flutter Android/iOS project'
gh repo create mauri-study-app --private --source . --remote origin --push
printf '\nGitHub Actions will generate a debug APK under the new repository Actions tab.\n'

#!/usr/bin/env bash
# Runs inside Ubuntu: download Engineer (if needed) and run its installer.
# Usage: bootstrap.sh REF   (REF is a branch, tag or commit of GSA/the_engineer)
set -euo pipefail

ref="${1:-main}"
repo="https://github.com/GSA/the_engineer.git"
dir="$HOME/engineer"

if ! command -v git >/dev/null || ! command -v python3 >/dev/null; then
    echo "Installing git and Python (Ubuntu may ask for your Ubuntu password)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq git python3
fi

if [ ! -d "$dir/.git" ]; then
    echo "Downloading Engineer into $dir ..."
    git clone --quiet "$repo" "$dir"
    if [ "$ref" != "main" ]; then
        git -C "$dir" fetch --quiet origin "$ref"
        git -C "$dir" checkout --quiet -B main FETCH_HEAD
        git -C "$dir" branch --quiet --set-upstream-to=origin/main main
    fi
fi

cd "$dir"
# --simple makes the optional developer tools and Copilot default to "no".
if grep -q -- '"--simple"' scripts/engineer.py; then
    exec ./engineer install --simple
fi
exec ./engineer install

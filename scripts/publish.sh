#!/bin/bash
# Publishes hooks.json to GitHub repository

cd /app/data

if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
    echo "[PUBLISH] GitHub not configured (GITHUB_TOKEN or GITHUB_REPO missing)"
    echo "[PUBLISH] Skipping push - hooks.json available locally at /app/data/hooks.json"
    exit 0
fi

echo "[PUBLISH] Publishing to GitHub: $GITHUB_REPO"

# Configure git
git config --global user.email "hook-service@osrs.bot"
git config --global user.name "OSRS Hook Service"

# Clone/update repo
if [ ! -d "/app/github-repo" ]; then
    echo "[PUBLISH] Cloning repository..."
    git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /app/github-repo
    if [ $? -ne 0 ]; then
        echo "[PUBLISH] ERROR: Failed to clone repository"
        exit 1
    fi
fi

cd /app/github-repo
git pull origin main || git pull origin master

# Copy hooks.json only (no backups)
cp /app/data/hooks.json .

# Check if there are changes
if git diff --quiet && git diff --staged --quiet; then
    echo "[PUBLISH] No changes to commit"
    exit 0
fi

# Commit and push
git add .
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git commit -m "Update hooks $TIMESTAMP"

if git push; then
    echo "[PUBLISH] Successfully pushed to GitHub: $GITHUB_REPO"
else
    echo "[PUBLISH] ERROR: Failed to push to GitHub"
    exit 1
fi

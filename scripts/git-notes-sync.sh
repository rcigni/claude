#!/usr/bin/env bash
# Sync git notes with a remote.
# Usage:
#   git-notes-sync.sh push [remote]   — push notes to remote (default: origin)
#   git-notes-sync.sh fetch [remote]  — fetch notes from remote (default: origin)
#   git-notes-sync.sh show [ref]      — show notes for a ref (default: HEAD)
#   git-notes-sync.sh log [range]     — show log with inline notes

set -euo pipefail

REMOTE="${2:-origin}"
REF="${2:-HEAD}"

case "${1:-help}" in
  push)
    git push "$REMOTE" refs/notes/commits
    echo "Pushed notes to $REMOTE"
    ;;
  fetch)
    git fetch "$REMOTE" refs/notes/commits:refs/notes/commits
    echo "Fetched notes from $REMOTE"
    ;;
  show)
    git notes show "$REF" 2>/dev/null || echo "No note for $REF"
    ;;
  log)
    RANGE="${2:-HEAD~10..HEAD}"
    git log --oneline --notes "$RANGE"
    ;;
  *)
    echo "Usage: git-notes-sync.sh {push|fetch|show|log} [remote|ref|range]"
    exit 1
    ;;
esac

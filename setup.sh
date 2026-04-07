#!/usr/bin/env bash
# Symlinks CLAUDE.md and modules into ~/.claude/ for global use.
# Run from this repo's root directory.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude"

mkdir -p "$TARGET_DIR"

# Symlink main CLAUDE.md
ln -sfn "$REPO_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"

# Symlink modules directory
ln -sfn "$REPO_DIR/modules" "$TARGET_DIR/modules"

# Symlink custom commands
ln -sfn "$REPO_DIR/commands" "$TARGET_DIR/commands"

echo "Linked CLAUDE.md, modules/, and commands/ into $TARGET_DIR"

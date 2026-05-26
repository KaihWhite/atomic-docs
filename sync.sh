#!/usr/bin/env bash
#
# sync.sh — keep this repo and the deployed Claude copy of the atomic-docs
# skill in sync.
#
# This repo is the authoritative source; `push` deploys it, `pull` is for
# recovering edits made directly to the deployed copy.
#
# Deploy mapping (repo  <->  deployed):
#   ./  (skill tree)  <->  $CLAUDE_DIR/skills/atomic-docs   (whole tree)
#
# Unlike a dedicated skill dir, this repo's root mixes skill content with repo
# meta, so EXCLUDES keep .git, README.md, and sync.sh itself out of the deployed
# copy. rsync --exclude also shields those paths from --delete, so `pull` will
# never wipe the repo-only files even though the deployed side lacks them.
# (Claude Code reads the skill from $CLAUDE_DIR/skills/atomic-docs, a real dir.)
#
# Usage:
#   ./sync.sh check   # report drift, exit 1 if any (default)
#   ./sync.sh diff    # show the actual diffs
#   ./sync.sh push    # repo  -> deployed
#   ./sync.sh pull    # deployed -> repo
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DEPLOYED="$CLAUDE_DIR/skills/atomic-docs"

# Repo-only paths that must never reach (or be deleted from) the deployed dir.
EXCLUDES=(--exclude '.git/' --exclude 'README.md' --exclude 'sync.sh')

mode="${1:-check}"

tree_in_sync() { # $1=src $2=dst -> 0 if identical by content (ignores mtime)
  [[ -d "$2" ]] || return 1
  [[ -z "$(rsync -rcin --delete "${EXCLUDES[@]}" "$1"/ "$2"/ 2>/dev/null)" ]]
}

case "$mode" in
  check)
    if tree_in_sync "$REPO_DIR" "$DEPLOYED"; then
      echo "OK    atomic-docs/"; echo "all in sync"
    else
      echo "DRIFT atomic-docs/"; echo "drift detected"; exit 1
    fi
    ;;
  diff)
    if tree_in_sync "$REPO_DIR" "$DEPLOYED"; then
      echo "OK    atomic-docs/"; echo "all in sync"
    else
      echo "DRIFT atomic-docs/"
      rsync -rcin --delete "${EXCLUDES[@]}" "$REPO_DIR"/ "$DEPLOYED"/ || true
      echo "drift detected"; exit 1
    fi
    ;;
  push)
    mkdir -p "$DEPLOYED"
    rsync -a --delete "${EXCLUDES[@]}" "$REPO_DIR"/ "$DEPLOYED"/ && echo "push  atomic-docs/"
    ;;
  pull)
    rsync -a --delete "${EXCLUDES[@]}" "$DEPLOYED"/ "$REPO_DIR"/ && echo "pull  atomic-docs/"
    ;;
  *)
    echo "usage: $0 {check|diff|push|pull}" >&2; exit 2;;
esac

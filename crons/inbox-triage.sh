#!/usr/bin/env bash
# inbox-triage.sh — classify, tag, and file every note in the Obsidian inbox
#
# Designed to be scheduled by Hermes cron OR a system crontab.
# Watchdog pattern: silent when inbox is empty.

set -euo pipefail

if [ -f "$HOME/.hermes/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$HOME/.hermes/.env"
  set +a
fi

VAULT="${OBSIDIAN_VAULT_PATH:-$HOME/Documents/Obsidian Vault}"
MAX_NOTES="${INBOX_TRIAGE_MAX_NOTES:-50}"

if [ ! -d "$VAULT" ]; then
  echo "FATAL: vault not found at $VAULT" >&2
  exit 1
fi

INBOX="$VAULT/Inbox"
mkdir -p "$INBOX" "$VAULT/Refs" "$VAULT/Refs/Ideas" "$VAULT/Meetings" "$VAULT/Projects"

# Fast path: empty inbox → silent exit (no LLM call, no token cost)
shopt -s nullglob
files=("$INBOX"/*.md)
shopt -u nullglob
if [ ${#files[@]} -eq 0 ]; then
  exit 0
fi

# NOTE: concurrency is handled INSIDE the obsidian-inbox-triage skill, which
# touches/deletes <vault>/Refs/.triage.lock itself. The wrapper must NOT create
# that lock or the skill sees it and exits immediately (deadlock).

export INBOX_TRIAGE_MAX_NOTES="$MAX_NOTES"

hermes chat -Q \
  --skills "obsidian,obsidian-inbox-triage" \
  -q "Triage the inbox at $INBOX (vault root: $VAULT). Follow the obsidian-inbox-triage skill exactly. Process at most $MAX_NOTES notes. Output only the one-line summary."

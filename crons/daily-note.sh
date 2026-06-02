#!/usr/bin/env bash
# daily-note.sh — generate today's Obsidian daily note
#
# Designed to be scheduled by Hermes cron OR a system crontab.
# Hermes cron is the recommended path — see install.sh.
#
# Watchdog pattern: silent when today's note already exists (no spam at 06:00),
# prints a one-line summary when the note is newly written, errors to stderr.

set -euo pipefail

# Load env (vault path, timezone)
if [ -f "$HOME/.hermes/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$HOME/.hermes/.env"
  set +a
fi

VAULT="${OBSIDIAN_VAULT_PATH:-$HOME/Documents/Obsidian Vault}"
TZ_NAME="${HERMES_DAILY_TZ:-$(cat /etc/timezone 2>/dev/null || echo UTC)}"

if [ ! -d "$VAULT" ]; then
  echo "FATAL: vault not found at $VAULT" >&2
  echo "Set OBSIDIAN_VAULT_PATH in ~/.hermes/.env or create the directory." >&2
  exit 1
fi

TODAY=$(TZ="$TZ_NAME" date +%Y-%m-%d)
NOTE_PATH="$VAULT/Daily/$TODAY.md"

if [ -f "$NOTE_PATH" ]; then
  # Already exists — silent exit (watchdog pattern).
  exit 0
fi

# Use hermes chat -q (quiet, one-shot) with the relevant skills preloaded.
hermes chat -Q -q \
  --skills "obsidian,obsidian-daily-note" \
  "Generate today's daily note ($TODAY) for the Obsidian vault at: $VAULT. Follow the obsidian-daily-note skill exactly. Output only the one-line success summary."

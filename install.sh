#!/usr/bin/env bash
# install.sh — one-shot installer for hermes-obsidian-pack
#
# Usage: ./install.sh [--dry-run]
#
# Does three things:
#   1. Copies the two skills into $HERMES_SKILLS_DIR (default ~/.hermes/skills/)
#   2. Copies the cron wrappers to ~/.hermes/scripts/ and chmods them
#   3. Registers two hermes cron jobs (daily 06:00 + hourly)
#
# Safe to re-run — it skips existing skill dirs unless --force is passed.

set -euo pipefail

DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

run() {
  echo "  $ $*"
  if [ "$DRY_RUN" -eq 0 ]; then "$@"; fi
}

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
SCRIPTS_DIR="$HOME/.hermes/scripts"

echo "==> hermes-obsidian-pack installer"
echo "    repo: $REPO_ROOT"
echo "    skills dir: $SKILLS_DIR"
echo "    scripts dir: $SCRIPTS_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "    DRY RUN — no changes will be made"
echo

# Sanity: hermes on PATH
if ! command -v hermes >/dev/null 2>&1; then
  echo "ERROR: 'hermes' not found on PATH." >&2
  echo "Install Hermes Agent first: https://hermes-agent.nousresearch.com/docs/" >&2
  exit 1
fi

# Sanity: vault path resolvable
VAULT_PATH=""
if [ -f "$HOME/.hermes/.env" ]; then
  # shellcheck source=/dev/null
  VAULT_PATH=$(grep -E '^OBSIDIAN_VAULT_PATH=' "$HOME/.hermes/.env" | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'") || true
fi
VAULT_PATH="${VAULT_PATH:-$HOME/Documents/Obsidian Vault}"

echo "==> Vault path: $VAULT_PATH"
if [ ! -d "$VAULT_PATH" ]; then
  echo "    WARNING: vault directory does not exist yet."
  echo "    Either create it now or set OBSIDIAN_VAULT_PATH in ~/.hermes/.env before the crons run."
fi
echo

# Step 1: skills
echo "==> Installing skills"
for skill in obsidian-daily-note obsidian-inbox-triage; do
  src="$REPO_ROOT/skills/$skill"
  dst="$SKILLS_DIR/$skill"
  if [ -d "$dst" ] && [ "$FORCE" -eq 0 ]; then
    echo "    [skip] $skill already installed at $dst (use --force to overwrite)"
    continue
  fi
  run mkdir -p "$SKILLS_DIR"
  run cp -r "$src" "$dst"
  echo "    [ok]  $skill -> $dst"
done
echo

# Step 2: cron wrappers
echo "==> Installing cron wrappers"
run mkdir -p "$SCRIPTS_DIR"
for script in daily-note.sh inbox-triage.sh; do
  src="$REPO_ROOT/crons/$script"
  dst="$SCRIPTS_DIR/$script"
  run cp "$src" "$dst"
  run chmod +x "$dst"
  echo "    [ok]  $dst"
done
echo

# Step 3: register cron jobs
echo "==> Registering cron jobs via 'hermes cron create'"

# Check for existing jobs with the same name to avoid duplicates.
existing=""
if hermes cron list 2>/dev/null | grep -E 'obsidian-(daily-note|inbox-triage)' > /tmp/.hop_existing 2>/dev/null; then
  existing=$(cat /tmp/.hop_existing)
fi
if [ -n "$existing" ]; then
  echo "    Found existing jobs with matching names:"
  echo "$existing" | sed 's/^/      /'
  echo "    Skipping registration. Remove them first with 'hermes cron remove <id>' if you want to reinstall."
else
  run hermes cron create '0 6 * * *' \
    --no-agent \
    --script "$SCRIPTS_DIR/daily-note.sh" \
    --name 'obsidian-daily-note'

  run hermes cron create '0 * * * *' \
    --no-agent \
    --script "$SCRIPTS_DIR/inbox-triage.sh" \
    --name 'obsidian-inbox-triage'
fi
rm -f /tmp/.hop_existing
echo

echo "==> Done."
echo
echo "Verify:"
echo "  hermes skills list | grep obsidian"
echo "  hermes cron list"
echo
echo "Next:"
echo "  1. Ensure OBSIDIAN_VAULT_PATH is set in ~/.hermes/.env"
echo "  2. Create the vault folders (Inbox/, Daily/, Projects/, etc.) — or copy sample-vault/"
echo "  3. Wait for 06:00 local for your first daily note, or trigger manually:"
echo "     hermes cron run <job-id>"

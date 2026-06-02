---
name: obsidian-daily-note
description: Generate today's daily note in an Obsidian vault by carrying forward yesterday's open todos, summarizing active projects, and adding an "on deck" section. Use for morning briefings, scheduled daily-note creation, or when the user asks for "today's note".
platforms: [linux, macos]
related_skills: [obsidian]
---

# Obsidian Daily Note

Generates a single markdown file at `<vault>/Daily/YYYY-MM-DD.md` containing:

1. **Carryover** — open todos (`- [ ]`) pulled from yesterday's daily note, with strikethrough on yesterday's copy so nothing is lost.
2. **On deck** — one-line summary per active project page (any `.md` under `<vault>/Projects/` that does NOT have `status: archived` in its frontmatter).
3. **Inbox count** — number of files in `<vault>/Inbox/` so the user sees the backlog.
4. **Scratchpad** — empty section for the user to write into during the day.

This skill assumes the `obsidian` skill is loaded for vault file I/O.

## Resolve vault path

1. Read `OBSIDIAN_VAULT_PATH` from `~/.hermes/.env` if present.
2. Fallback to `~/Documents/Obsidian Vault`.
3. Verify the resolved path exists. If not, abort with a clear error — do NOT create a vault.

## Step 1: Find yesterday's note

- Compute yesterday's date in `YYYY-MM-DD` (use the host's local TZ, not UTC, unless `HERMES_DAILY_TZ` env var is set).
- Path: `<vault>/Daily/<yesterday>.md`.
- If missing, look back up to 7 days for the most recent daily note. If still nothing, skip Step 2 (no carryover).

## Step 2: Extract open todos

- Read yesterday's note with `read_file`.
- Match lines `^\s*- \[ \] .+$` — these are open todos.
- Ignore lines with `- [x]` (done) or `- [-]` (cancelled, optional convention).
- Collect the todo text verbatim, preserving any wikilinks or tags.

## Step 3: Mark yesterday's todos as carried

- For each open todo on yesterday's note, replace `- [ ]` with `- [>]` (Obsidian renders this as a "forwarded" checkbox if the user has the `Tasks` plugin; otherwise it shows as a literal `>` and still signals intent).
- Use `patch` with `replace_all=false` per todo so collisions on identical todo text are surfaced.

## Step 4: Summarize active projects

- List `<vault>/Projects/*.md` with `search_files target=files`.
- For each project file:
  - Read the first 30 lines.
  - If frontmatter contains `status: archived` (or `archived: true`), skip.
  - Extract the project title (first `# ` heading or filename without `.md`).
  - Extract the first non-empty line after the heading that is NOT frontmatter and NOT a heading — that's the "elevator pitch" line.
  - Emit `- [[Project Name]] — <elevator pitch>`.

## Step 5: Count inbox

- `search_files target=files pattern="*.md" path="<vault>/Inbox"` → count results.

## Step 6: Write today's note

Path: `<vault>/Daily/<today>.md`.

Use this template exactly (substitute `<...>` values):

```markdown
---
date: <YYYY-MM-DD>
type: daily
---

# <YYYY-MM-DD> — <Day of week>

## Carryover from [[<yesterday-date>]]

<carryover todos as `- [ ]` items; if none, write "_Nothing carried forward._">

## On deck

<project lines; if none, write "_No active projects._">

## Inbox

<N> note(s) waiting in [[Inbox]].

## Notes


```

(Trailing blank line under `## Notes` is intentional — gives the user a cursor target.)

If today's note already exists, abort. Do NOT overwrite — the user may have already written in it. Print a clear message and exit cleanly.

## Pitfalls

- **TZ drift**: cron runs in UTC by default. A 06:00 UTC cron in CET is 07:00/08:00 local — fine. But if the user is in PST, 06:00 UTC = 22:00 the night before. Honor `HERMES_DAILY_TZ` env var if set.
- **Vault on a synced filesystem**: if the vault is rsync'd from a Mac, writes during the rsync window can be clobbered. The recommended setup is VPS-authoritative + Mac pulls, so this skill writing on the VPS is the source of truth.
- **Frontmatter parsing**: don't pull in `pyyaml` for this — frontmatter is bounded by `---` lines at the top. Read first 20 lines, grab the block between the two `---`, do line-by-line `key: value` parsing. Good enough.
- **Project files with no body**: if a project page is just a heading, emit `- [[Project Name]] — _no description_` rather than skipping. Visibility matters.
- **Idempotence**: re-running on the same day must be a no-op (the abort-if-exists check above handles this).

## Verification

After writing, `read_file` the new note and confirm:
- It has all six sections.
- Carryover count matches what you extracted in Step 2.
- Project count matches what you summarized in Step 4.

Report to the user: "Wrote Daily/YYYY-MM-DD.md — N todos carried, M projects on deck, K inbox items."

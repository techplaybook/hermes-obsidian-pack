---
name: obsidian-inbox-triage
description: Scan an Obsidian vault's Inbox/ folder, classify each note, file it into the right destination folder, add tags, and link to existing project pages. Use for periodic vault cleanup or when the user dumps rough notes and wants them organized.
platforms: [linux, macos]
related_skills: [obsidian]
---

# Obsidian Inbox Triage

Processes every `.md` file in `<vault>/Inbox/`. For each one:

1. Classifies the note into a category.
2. Adds frontmatter (date, source, tags).
3. Inserts wikilinks to relevant project pages.
4. Moves the file to the right destination folder.
5. Leaves a one-line log entry per processed note.

Assumes the `obsidian` skill is loaded for vault file I/O.

## Categories and destinations

| Category | Destination | Trigger signals |
|----------|-------------|-----------------|
| Meeting note | `Meetings/` | mentions a date+time, attendees, "call with", "meeting with", "1:1" |
| Web clip / reference | `Refs/` | starts with a URL, contains a "Source:" line, or is mostly an excerpt |
| Project update | `Projects/<existing>.md` (append) | mentions a project name that already exists as a project page |
| Idea / fleeting | `Refs/Ideas/` | short (<300 chars), no clear action, no project match |
| Todo / action | leave in Inbox, just add tags | starts with `TODO`, has `- [ ]` items, asks a question |

When uncertain, default to `Refs/` and tag `#triage/uncertain` so the user can review.

## Resolve vault path

Same as `obsidian-daily-note`: env var `OBSIDIAN_VAULT_PATH` → fallback `~/Documents/Obsidian Vault`.

## Step 1: List inbox

`search_files target=files pattern="*.md" path="<vault>/Inbox"`.

If the result is empty, exit cleanly with "Inbox empty — nothing to triage." Do NOT proceed.

## Step 2: Load project page index

Before processing notes, build a list of existing project page names:

- `search_files target=files pattern="*.md" path="<vault>/Projects"`.
- Strip `.md`, keep the basename. This is your project alias list.
- Also read the frontmatter `aliases:` field of each project page if present — those are alternate names that should match too.

## Step 3: Process each inbox note

For each file in inbox order (oldest mtime first):

### 3a. Read

`read_file` the full note.

### 3b. Classify

Apply the rules in the Categories table. Use these heuristics in order:

1. **Project match first** — if the note body contains any project alias (case-insensitive, word-boundary match), classify as Project update.
2. **Meeting signals** — date+time pattern like `\b\d{1,2}:\d{2}\b` plus a name, OR a heading like `# Call with X`.
3. **URL-first** — first non-frontmatter line starts with `http://` or `https://`.
4. **Action signals** — contains `- [ ]` checkbox or starts with `TODO`/`ACTION:`.
5. **Length-based fallback** — under 300 chars and no other signal → fleeting idea.
6. **Default** — `Refs/` with `#triage/uncertain`.

### 3c. Enrich

Add or update frontmatter at the top of the note:

```yaml
---
date: <YYYY-MM-DD from file mtime>
type: <meeting|ref|idea|todo|project-update>
source: inbox-triage
tags: [<auto-tags>]
---
```

Auto-tags:
- Add `#meeting` for meetings.
- Add `#clip` for URL-first notes.
- Add `#idea` for fleeting.
- Add `#triage/uncertain` only when classification fell to default.

### 3d. Insert wikilinks

For each project alias detected in the body, replace the first occurrence with `[[Project Name]]` (preserve original casing in display: `[[Project Name|original text]]` if they differ).

Do this with `patch`, NOT a global regex on the file — you want to surface conflicts, not silently rewrite.

### 3e. Move / append

- **Meeting**: rename to `<YYYY-MM-DD> — <title>.md` and move to `Meetings/`. Title = first heading or first line if no heading.
- **Ref / clip / idea**: keep filename, move to `Refs/` (or `Refs/Ideas/` for fleeting).
- **Project update**: append the body (without frontmatter) under a `## YYYY-MM-DD HH:MM update` heading at the end of `Projects/<project>.md`. DELETE the inbox file after successful append.
- **Todo**: leave in `Inbox/`, just write the enriched frontmatter back. These need human attention.

Use `terminal` for moves (`mv`) since `write_file`+delete is two ops and risks data loss if the second fails.

### 3f. Log

Maintain a log at `<vault>/Refs/_triage-log.md`. Append one line per processed note:

```
- YYYY-MM-DD HH:MM — `<original-filename>` → <category> → `<new-path>` [<tags>]
```

## Safety rules

- **Never delete content.** Moves and appends only. The only deletion is the inbox source file AFTER its content has been confirmed appended to a project page (read it back, grep for a marker, then delete).
- **Idempotence on todos**: a note classified as todo and left in inbox must classify the same way on the next run — don't add `#triage/uncertain` to it, since the user is intentionally letting it sit.
- **Skip files starting with `_`** — those are vault metadata (like `_triage-log.md`).
- **Skip files with frontmatter `triage: skip`** — user override.
- **Concurrency**: the cron runs hourly. If a previous run is still going, the file lock at `<vault>/Refs/.triage.lock` (touch on start, delete on exit) should make a second run exit immediately. Stale lock >1h → ignore.

## Verification

After processing all notes:
- Count input files (Step 1) vs output destinations.
- Confirm inbox count decreased by (input - todos left in inbox).
- Read the last N lines of `_triage-log.md` to confirm log entries match.

Report: "Triaged N notes — A meetings, B refs, C ideas, D project updates, E todos remained in inbox."

## Pitfalls

- **Frontmatter without trailing `---`**: malformed files crash naive parsers. Wrap the parse in try/except, on failure treat the whole file as body with no frontmatter.
- **Project alias collisions**: if "API" is a project alias and the note mentions "API rate limits" generically, you'll false-positive. Mitigation: require alias matches to be either (a) inside a `[[wikilink]]` already, (b) followed by a colon/dash, or (c) the first word of a line. Otherwise classify as Ref.
- **Long inbox**: if there are 200+ files, the run may exceed a turn budget. The cron wrapper should pass `MAX_NOTES=50` env var and the skill should honor it, leaving the rest for the next hour.
- **Filename clashes on move**: if `Refs/2026-06-02 — call.md` already exists, append ` (2)` before `.md`. Don't overwrite.

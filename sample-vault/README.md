# Sample vault — Hermes + Obsidian pack

This is a reference folder structure. Copy it to wherever you want your real vault to live, then point `OBSIDIAN_VAULT_PATH` at it:

```bash
cp -r sample-vault ~/Obsidian/MyVault
echo 'OBSIDIAN_VAULT_PATH=$HOME/Obsidian/MyVault' >> ~/.hermes/.env
```

Folders you'll see:

- `Inbox/` — drop rough notes here from anywhere. The hourly triage cron processes them.
- `Daily/` — the daily-note cron writes to `Daily/YYYY-MM-DD.md` every morning.
- `Projects/` — one markdown file per active project. Used by both crons.
- `Meetings/` — where triage files notes it classifies as meetings.
- `Refs/` — where triage files clips and references. Contains `_triage-log.md`.
- `Refs/Ideas/` — fleeting short notes go here.
- `Clips/` — reserved for the web-clip recipe (separate deliverable).

Two placeholder files are included so you can see the conventions:

- `Projects/Example Project.md` — minimum project page with frontmatter.
- `Inbox/.gitkeep` — keeps the empty folder under version control.

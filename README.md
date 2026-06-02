# Hermes + Obsidian Pack

Two Hermes skills and two cron jobs that make your Obsidian vault populate and organize itself.

This is a companion to the [Hermes + Obsidian video](#) — drop it on your VPS, point it at a vault, and you wake up to a populated daily note and a triaged inbox every morning.

**The mental model:** the vault is just a folder of markdown files. Hermes (on your VPS) writes to it. Obsidian (on your laptop) reads from it. You sync the folder between them with whatever sync tool you like — rsync, Syncthing, Obsidian Sync, iCloud. The skills and crons here don't care which.

---

## What's in here

```
hermes-obsidian-pack/
├── skills/
│   ├── obsidian-daily-note/      # Generates today's daily note
│   └── obsidian-inbox-triage/    # Classifies + files Inbox notes
├── crons/
│   ├── daily-note.sh             # 06:00 wrapper for the daily-note skill
│   └── inbox-triage.sh           # Hourly wrapper for the inbox-triage skill
├── sample-vault/                 # Reference folder structure
├── install.sh                    # One-shot installer
└── README.md
```

### The skills

**`obsidian-daily-note`** — generates `Daily/YYYY-MM-DD.md` with:
- Open todos from yesterday's note, carried forward
- A one-line summary per active project page
- The current inbox count
- An empty scratchpad section for the day

**`obsidian-inbox-triage`** — scans `Inbox/`, classifies each note (meeting, ref, idea, project update, todo), adds frontmatter and tags, inserts wikilinks to existing project pages, and files each note in the right folder.

Both skills assume the built-in `obsidian` skill (vault file I/O) is also loaded.

### The crons

The crons are thin shell wrappers around `hermes chat -q --skills ...`. They follow the watchdog pattern — silent when there's nothing to do (so 06:00 doesn't spam you when the note already exists, and an empty inbox doesn't burn tokens).

The recommended installation uses Hermes's built-in cron scheduler (`hermes cron create`), not system `crontab`, so the jobs are visible to `hermes cron list` and can be paused/resumed without editing files.

---

## Install

### Prerequisites

1. Hermes Agent installed and configured (`hermes doctor` passes).
2. An Obsidian vault somewhere accessible to the VPS user. Set the path in `~/.hermes/.env`:
   ```
   OBSIDIAN_VAULT_PATH=/root/Obsidian/MyVault
   ```
   Default if unset: `~/Documents/Obsidian Vault`.
3. The built-in `obsidian` skill (ships with Hermes — `hermes skills list | grep obsidian`).

### One-shot installer

```bash
git clone https://github.com/pawel-cell/hermes-obsidian-pack.git
cd hermes-obsidian-pack
./install.sh
```

`install.sh` does three things:
1. Copies the two skills into `~/.hermes/skills/`.
2. Copies the two cron wrappers to `~/.hermes/scripts/` and `chmod +x` them.
3. Registers the cron jobs via `hermes cron create`.

After install, verify:

```bash
hermes skills list | grep obsidian
hermes cron list
```

You should see both skills and both jobs.

### Manual install (if you want to see what's happening)

```bash
# Skills
cp -r skills/obsidian-daily-note    ~/.hermes/skills/
cp -r skills/obsidian-inbox-triage  ~/.hermes/skills/

# Cron wrappers (any location works; ~/.hermes/scripts/ is conventional)
mkdir -p ~/.hermes/scripts
cp crons/*.sh ~/.hermes/scripts/
chmod +x ~/.hermes/scripts/*.sh

# Schedule via Hermes cron (preferred)
hermes cron create '0 6 * * *' \
  --no-agent \
  --script ~/.hermes/scripts/daily-note.sh \
  --name 'obsidian-daily-note'

hermes cron create '0 * * * *' \
  --no-agent \
  --script ~/.hermes/scripts/inbox-triage.sh \
  --name 'obsidian-inbox-triage'
```

`--no-agent` means the cron runs the shell script directly with no extra LLM call wrapping it; the script itself invokes `hermes chat -q --skills ...` when it has actual work to do. This keeps the watchdog pattern intact: empty inbox = zero tokens.

### System crontab alternative

If you'd rather use system cron:

```cron
0 6 * * *  /root/.hermes/scripts/daily-note.sh    >> /var/log/hermes-daily-note.log    2>&1
0 * * * *  /root/.hermes/scripts/inbox-triage.sh  >> /var/log/hermes-inbox-triage.log  2>&1
```

Make sure `hermes` is on PATH for the cron user, or use the full path (`/usr/local/bin/hermes`).

---

## Vault layout

The skills assume this folder structure under your vault root:

```
<vault>/
├── Inbox/         # You dump rough notes here. Triage empties it.
├── Daily/         # Daily notes. obsidian-daily-note writes here.
├── Projects/      # One .md per active project. Use `status: archived` frontmatter to hide from on-deck.
├── Meetings/      # Where triage files meeting notes.
├── Refs/          # Where triage files clips, ideas, and unclear notes.
│   ├── Ideas/     # Fleeting short notes.
│   └── _triage-log.md  # Auto-maintained log of triage decisions.
└── Clips/         # (Optional) Reserved for the web-clip recipe (separate video).
```

A `sample-vault/` directory in this repo shows the structure with placeholder files. You can copy it as a starting point:

```bash
cp -r sample-vault ~/Obsidian/MyVault
```

Then point `OBSIDIAN_VAULT_PATH` at it.

---

## How to use it from your Mac

The skills run on the VPS. You read and edit on your Mac in Obsidian. The sync between them is your problem (intentionally — there's no one right answer).

The cheapest setup that works for most people:

1. Make your VPS vault directory the source of truth.
2. On your Mac, install [Mountain Duck](https://mountainduck.io/) or just use `rsync` from a launchd job to pull the vault down to `~/Obsidian/MyVault` every minute.
3. Open the local `~/Obsidian/MyVault` folder as an Obsidian vault.
4. When you create new notes on the Mac, push back to the VPS — same rsync command in reverse.

If you want bidirectional with conflict handling, use Syncthing.

If you're already paying for Obsidian Sync, just run the VPS as the writer and let Obsidian Sync do the rest from the Mac side — open the vault in Obsidian on both ends and turn on Obsidian Sync against the same remote.

The skills don't care which approach you pick. They just write files.

---

## Customising

### Change the daily-note template

Edit `~/.hermes/skills/obsidian-daily-note/SKILL.md`. The template literal is in Step 6.

### Change the triage categories

Edit `~/.hermes/skills/obsidian-inbox-triage/SKILL.md`. The Categories table near the top is where the rules live; the heuristics in Step 3b are where to add new signals.

### Change the schedule

```bash
hermes cron list                              # find the IDs
hermes cron edit <id>                         # interactive editor
# or remove and recreate with a new cron expression
```

### Per-project timezone

The daily-note cron honours `HERMES_DAILY_TZ` in `~/.hermes/.env`:
```
HERMES_DAILY_TZ=Europe/Warsaw
```

### Limit triage batch size

Inbox with hundreds of notes? Set in `~/.hermes/.env`:
```
INBOX_TRIAGE_MAX_NOTES=20
```
The remaining notes get picked up on subsequent hourly runs.

---

## Troubleshooting

**"vault not found at ..."** — `OBSIDIAN_VAULT_PATH` is unset or wrong. Check `~/.hermes/.env`.

**Daily note didn't appear in the morning** — check the cron ran:
```bash
hermes cron list
hermes logs | grep obsidian-daily-note | tail -20
```

**Triage moved a note to the wrong place** — open `<vault>/Refs/_triage-log.md`. Every decision is logged. If you see a pattern, edit the heuristics in the triage skill and tighten the rules. Skills are markdown — edit and save, no rebuild needed.

**Triage skipped a note** — files starting with `_` are intentionally skipped (vault metadata). Files with `triage: skip` in frontmatter are also skipped (user override).

**Two crons running at once on a large inbox** — there's a lockfile at `<vault>/Refs/.triage.lock`. Stale locks older than 1h are auto-cleared.

---

## Why these specific deliverables?

This pack covers the two most common "I have an Obsidian vault but never open it consistently" failure modes:

1. **You don't open the daily note unless something pulls you in.** The autogen daily note pulls forward yesterday's todos, surfaces your projects, and counts your inbox — so opening Obsidian in the morning has immediate signal.
2. **You dump notes into Inbox and never process them.** Hourly triage means the inbox is always small enough to actually look at.

Both are real time-savings that compound over weeks. No fake "second brain" framing — just two crons that close two specific loops.

---

## License

MIT. Fork it, change it, ship it.

## Credits

Built on top of the official Obsidian skill that ships with Hermes Agent (by Hermes team) and the agent-skills patterns published by Steph Ango / kepano (Obsidian CEO).

---
name: atomic-docs
description: >
  Use when wrapping up a non-trivial code change (renamed/added/removed
  symbols, changed signatures, moved files, shipped tasks), or when asked to
  backfill or bootstrap a project's docs. Skip trivial formatting,
  non-compiling WIP, or pure code reads.
---

# Atomic Docs — Code and Documentation in One Commit

Discipline source for keeping code and project documentation in sync. Every code change ships with its matching doc updates — including the project's live docs (state, worklog, reference) — in the **same commit**, gated by a mechanical drift-prevention check before the task is declared done.

**REQUIRED BACKGROUND:** `superpowers:verification-before-completion` (evidence over assertion before declaring done).

**REQUIRED SUB-SKILL:** Step 6's optional sub-agent verification uses `superpowers:dispatching-parallel-agents`.

Project-specific overrides (live-doc paths, file-size thresholds, worklog rotation, archive policies) live in the project's `CLAUDE.md`, not here.

## The Atomicity Rule

A commit that changes a function signature without updating the doc that quotes it is a drift event waiting for a future audit. Reviewers (human or Claude) reading a code+doc commit verify both halves stay consistent in one pass; splitting them invites the doc half to be silently dropped. "Matching doc update" means: every doc that references a touched symbol or covers a touched file either (a) still describes current behaviour or (b) has been edited in this commit. Step 1's check is the mechanical proof of (a) and surfaces what needs to become (b).

## The Live Docs

Three documents every run maintains. Defaults below; a project's `CLAUDE.md` may override the paths.

| Doc | Holds | Write mode |
|-----|-------|------------|
| `docs/state.md` | Where the project is *now* — status, next steps, issues | Rewritten in place every run |
| `docs/worklog.md` | What happened and why — work done, decisions, lessons | Append-only, newest at the bottom |
| `docs/reference/<feature>.md` | Deep dive on one feature / system / component | Rewritten to current state |

**`state.md`** fits on one screen and holds no history. Finished items are deleted, not checked off — the worklog entry records them.

```markdown
---
last_updated: 'YYYY-MM-DD'
---
# Project State
## Status          <!-- 2–5 lines: what works today, overall phase -->
## In Progress     <!-- partially built work, linking its reference docs -->
## Next Steps      <!-- ordered; top = do next -->
## Known Issues    <!-- current bugs, tech debt, blockers -->
## Open Questions  <!-- undecided design calls -->
```

**`worklog.md`** gets one entry per run, appended at the bottom. Earlier entries are never edited — corrections go in a new entry. Omit an empty bullet except **Done**. No commit hash (it doesn't exist yet); `git log -- docs/worklog.md` links entries to commits. No `last_updated` frontmatter — each heading carries its date. To read recent context, `Grep` for `^## ` and `Read` from the last few headings; never the whole file.

```markdown
## YYYY-MM-DD — <past-tense summary>
- **Done:** <what shipped>
- **Decisions:** <what was chosen, why, what was rejected>
- **Lessons:** <what surprised you; what to do differently next time>
```

**`reference/<feature>.md`** exists for every feature that owns its own files or public interface (class, module, service, autoload). Helpers and small changes belong in their parent feature's doc. `sources:` is required — the files and directories the doc covers (a directory covers everything under it); it drives Step 1's path check.

```markdown
---
last_updated: 'YYYY-MM-DD'
sources:
  - src/importer/
  - src/shared/delimiters.py
---
# <Feature>
## Purpose               <!-- what it's for, 2–3 lines -->
## How It Works          <!-- current behaviour, data flow, state -->
## Key Files & Symbols   <!-- path → role; public symbols with signatures -->
## Interfaces            <!-- events/signals, APIs, config it exposes or consumes -->
## Invariants & Gotchas  <!-- rules that must hold; past-bug guards as current-state rules -->
## Related               <!-- other reference docs -->
```

**Existing project without reference docs?** Read `backfill.md` in this skill's directory.

## Step 1 — Drift-Prevention Check (mechanical, non-skippable)

Before declaring the task done, run three checks across the project's docs directory.

**Name grep** — identify every symbol the change touches and `Grep` for it.

- **Renamed / added / removed function or method**: `Grep` for the function name. Each hit must be verified or edited.
- **Changed function signature** (added / removed / renamed param, return type): `Grep` for the function name; check that doc snippets show the current signature.
- **Renamed / added / removed exported type, class, event, or globally-registered service** (e.g. classes, signals/events, autoloads, registered handlers, exported constants): `Grep` for the name. Registry-style mentions are the highest drift risk.
- **Renamed / moved file**: `Grep` for the old path or filename. Reference docs' `sources:` and the project's file registry (if any) are the most likely targets.
- **Shipped task**: `Grep` for the task ID. Past-tense any "TASK-XYZ will ship Y" → "TASK-XYZ shipped Y", or drop the reference per the doc-rewrite discipline below.

**Path check** — for each changed code file (`git status --short`), `Grep` `docs/reference/` for the file's path and each parent directory (`src/importer/csv_parser.py`, `src/importer/`, `src/`). Every doc whose `sources:` matches needs its behaviour sections read against the change. This catches what name grep can't: new behaviour behind an unchanged name — a tuned constant, a new state, an altered flow.

**Missing reference doc** — if the change adds a feature (new files or a new public interface) and no `sources:` entry covers those files, Step 2 creates its reference doc.

**No hits** = symbol is undocumented. Fine for internals; suspect for a public API.

**Hits** = each one needs a quick read to confirm accuracy or an edit if it's stale. Frozen archive notes (e.g. `*-archived-*.md`) and worklog entries are exempt — they're historical records by design.

## Step 2 — Apply Doc Updates

**Create what's missing first**, in this same commit:

- **Reference doc** flagged by Step 1: `Write` it from the template, filled with what you learned making the change. You'll never have more context on this feature than right now.
- **`state.md` / `worklog.md`** absent: `Write` a starter from the template. Fill `state.md`'s Status from what you know of the project; the worklog's first entry is this run's (Step 3).

Then pick the cheapest tool for each edit. Writes go through `Edit` (or `Write` for new files / full rewrites); reads through `Read` (with `offset` / `limit` for large files) or `Grep` for locating sections.

- **Frontmatter edits**: `Edit` on the specific YAML line — e.g. `last_updated: '<old>'` → `last_updated: '<new>'`. Each frontmatter field is unique within a note, so the `old_string` is naturally unambiguous. Batch parallel `Edit` calls for multi-file restamps.
- **Small note edits**: `Edit` with surgical `old_string` / `new_string`. Read first if the exact text isn't in your context. `Write` only for full rewrites or genuinely new files.
- **Large file** (multi-hundred-KB; project-specific list lives in `CLAUDE.md`): `Grep` to locate, `Read` with `offset` / `limit` for targeted lines, `Edit` for the change. Never read the whole file.
- **Batch over sequential**: parallel `Read` / `Edit` calls in one message when files are independent.
- **Don't re-read after edit**: `Edit` errors on `old_string` mismatch; a successful return means the change landed.
- **Search, don't browse**: `Grep` with file globs beats listing directories.

`Bash` is for `git`, read-only commands, and coordination — not file writes. Sandboxed environments may silently no-op `sed -i` and similar; reserve `Bash` for tasks `Edit` can't do.

## Step 3 — Update State + Append Worklog (every run, non-skippable)

1. **`state.md`** — rewrite each section the change affects: delete finished items from In Progress / Next Steps, add follow-ups the change created, add or remove Known Issues and Open Questions. Status changes only when the project's overall picture did.
2. **`worklog.md`** — append one entry from the template at the bottom. **Decisions** records choices with their *why*; **Lessons** records surprises worth remembering. A routine change may be a one-line **Done** — but the entry is never skipped.

## Step 4 — Restamp `last_updated`

After applying edits, restamp the `last_updated` frontmatter on **every modified note** — `state.md`, edited reference docs, any other edited note — with an `Edit` on the YAML line. Format follows the project's existing convention — read one neighbouring note if unsure (typically `'YYYY-MM-DD'`). The worklog has no `last_updated`.

**Don't restamp notes you read but didn't change.** A restamp signals "content changed today", not "I looked at this". Future audits depend on the distinction.

## Step 5 — Stage + Draft Commit (don't commit yet)

1. **Stage the atomic set.** `git add` every file touched by this task — code + matching doc edits + `state.md` + `worklog.md` + any new reference docs + implementation-plan / archive / instructions changes. One staging step, scoped to the work that just happened. Don't sweep up unrelated WIP.
2. **Inspect.** `git status` to confirm everything intended is staged and nothing extra. `git diff --cached --stat` for a quick what-changed summary.
3. **Draft a tight message — one line by default, two lines max.** Acceptable shapes: a single subject line; `subject -- rationale` on one line; or subject + one body line after a blank. **No multi-paragraph bodies** — the worklog entry carries the detail. Match the project's existing tone (run `git log -5 --oneline` if unsure); past-tense summary of what shipped. No Conventional Commits prefix unless the repo uses one.

## Step 6 — Present, Offer Verification, Await Approval

1. **Present.** Show the user the staged set + draft message.
2. **Offer the optional Explore sub-agent diff verification** before they commit:

> "Want me to dispatch an Explore sub-agent (Sonnet) to diff-walk this commit and cross-check against the docs you updated? It catches symbols the Step 1 check missed — registry rows, exported fields hidden in refactors, public-API additions outside your mental model. Recommended for multi-file or cross-cutting changes; skip for single-symbol renames already verbally walked."

If the user says yes, dispatch:

```
Agent({
  subagent_type: "Explore",
  model: "sonnet",
  prompt: "Walk `git diff --cached` on touched code paths (or `git show HEAD --stat` if already committed). For each public symbol added/removed/renamed/signature-changed, and each changed file under a `docs/reference/*.md` `sources:` entry, cross-reference against the docs also touched in this commit. Report uncovered drift in <500 words. Skip `docs/worklog.md`, archives (`*-archived-*.md`), audits, design scratchpads."
})
```

**Verify each finding against primary evidence yourself before acting** — read the cited code + doc lines directly. Sub-agents hallucinate severity, misread context, or cite wrong line numbers. Primary-source verification keeps the dispatch trustworthy.

If gaps found → fix inline (back to Step 2) → restamp affected notes (Step 4) → re-stage + re-present (Step 5) → re-offer this step. If clean, advance.

3. **Wait for explicit commit approval.** The user owns the `git commit` invocation. **Approval signals**: the words `commit`, `ship`, `go`, or a revised commit message the user wrote. **Not approval**: ambiguous affirmations like "looks good", "tie loose ends", "wrap it up", "finish", "let's go", or silence — these often mean "finish presenting the diff", not "execute the commit". When in doubt, ask: "commit with this message?"

The discipline is about atomicity, not autonomy. The skill handles the scaffolding; the user keeps editorial control.

## Doc Rewrite Discipline

Reference docs and other feature notes describe **current state in present tense**. They do not accrete task-by-task changelogs. History goes in the worklog. When a task changes a system:

- **Rewrite the affected paragraph** to describe how the system works now. Don't append "TASK-XYZ added Y" / "Bug-fix Patch N corrected Z".
- **Drop date-stamped task references** from prose (`(TASK-F09, 2026-04-28)`). The worklog + git blame carry the provenance.
- **Keep load-bearing architecture rules** that protect against re-introducing past bugs. State the rule under Invariants & Gotchas; put the story of the bug in the worklog's Lessons.
- **Don't add per-note History sections.** History lives in the worklog and `git log`.

If a future reader couldn't tell from the note alone what the system *does today* without reconstructing a sequence of tasks, the rewrite isn't done.

## Worked Example: Renaming + Re-Signing a Function

Code change: renamed `parse_csv_row()` → `parse_record()` in `src/importer/csv_parser.py` and added an optional `delimiter` parameter.

1. **Drift check**:
   - Name grep for `parse_csv_row` across `docs/`: hits in `reference/importer.md` (Key Files table), `archive/import-v1-archived-2025-08.md`, and an old `worklog.md` entry. `Grep` for `parse_record` confirms no pre-existing collision.
   - Path check: `reference/importer.md` lists `src/importer/` in `sources:` — its How It Works says imports are "comma-delimited only". Name grep never hit that sentence.
   - Missing doc: no new feature — nothing to create.
2. **Triage hits**:
   - `reference/importer.md`: **edit the table row** to `parse_record(row, delimiter=',')`; **rewrite** the How It Works sentence to describe the delimiter parameter.
   - Archive note and old worklog entry: **leave them** — frozen history.
3. **Apply edits**: `Edit` on `reference/importer.md`.
4. **State + worklog**: in `state.md`, delete Next Steps item "Add delimiter support for TSV import", add "Detect `.tsv` extension and pass `delimiter='\t'`". Append:
   ```markdown
   ## 2026-05-02 — Renamed parse_csv_row to parse_record, added delimiter param
   - **Done:** Renamed parser entry point; optional `delimiter` defaults to `,`.
   - **Decisions:** Kept comma default so existing callers needn't change.
   ```
5. **Restamp**: `last_updated` → today on `reference/importer.md` and `state.md`. Archive and worklog untouched.
6. **Stage + draft + present**: `git add` parser module + `reference/importer.md` + `state.md` + `worklog.md`. `git status` confirms the atomic set. Draft: *"Rename parse_csv_row to parse_record, add delimiter param"*.
7. **Offer sub-agent verification**. If yes → dispatch Explore (Sonnet) → handle any gaps. If no → wait for explicit commit approval.

## Red Flags — STOP and Re-Check

Self-check signals you're rationalizing past the discipline:

- "Change is small, drift check feels like overkill" → Step 1 is non-skippable. Small changes are when drift slips through.
- "I already mentally walked the docs" → Mental walks miss hits. Run the grep and the path check.
- "Name grep came back clean, docs are fine" → Behaviour changes hide behind unchanged names. Run the path check.
- "User said 'looks good', I'll commit" → Not approval. Wait for `commit`, `ship`, `go`, or a revised message.
- "I'll restamp every note I opened" → Restamp means changed, not viewed.
- "Just append a TASK-XYZ note at the bottom" → Notes describe current state, not history. Rewrite the prose; history goes in the worklog.
- "I'll tick it ✅ in state.md" → Delete it. The worklog entry records that it was done.
- "Old worklog entry has a typo / old name, I'll fix it" → Append-only. Correct it in a new entry.
- "Archive note has the old name, I'll fix that too" → Archives are frozen. Leave them.
- "Sub-agent verification is overkill, I'll skip the offer" → The user opts in or out; you don't decide for them on non-trivial changes.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Single-line change, no docs to update" | Public symbols → grep. Internal symbols → maybe; check anyway. |
| "Grep hits look fine on a skim" | Skim ≠ verify. Read each hit's surrounding context. |
| "Too small for a worklog entry" | A one-line **Done** is fine. Skipping the entry isn't. |
| "I'll write the reference doc later" | Later has less context than now. Create it in this commit. |
| "User said 'wrap it up' = commit" | Ambiguous affirmations finish the *presentation*, not the *commit*. Ask. |
| "Sub-agent step is overkill, I'll skip" | The user opts in or out; *you* unilaterally skipping it for non-trivial changes is a discipline violation. |
| "Restamping read-only notes is harmless" | It corrupts the audit signal. Future audits will mistrust timestamps. |
| "I'll add a History section" | The worklog + git log carry history. Note prose stays present-tense. |
| "Archive references old name; I'll fix it" | Archives are frozen historical records. Leave them. |

## Anti-Patterns

- **Skipping the drift check "because the change was small"** — exactly when drift slips through.
- **Trusting partial grep coverage** — `Grep` finds what you grep'd for, not what you forgot. The path check and Step 6's sub-agent verification are the backstops.
- **Letting `state.md` accrete** — once it scrolls past a screen, it's turning into a worklog. Prune finished and stale items.
- **Relaying sub-agent findings as fact** — the agent cites code + doc lines; read both yourself before acting or surfacing the gap.

---
name: atomic-docs
description: >
  Use when a non-trivial code change is wrapping up — renamed/added/removed
  symbols, changed signatures, moved files, shipped tasks — even if the user
  just says "ship it", "wrap up", "ready to commit", or "finish the task"
  without naming docs explicitly. Also activate on direct doc requests:
  "update docs", "sync docs", "fix doc drift", "rewrite the feature/component
  note for X". Skip for trivial formatting (whitespace, comment-only edits),
  WIP code that doesn't compile, or pure code reads where nothing changed.
---

# Atomic Docs — Code and Documentation in One Commit

Discipline source for keeping code and project documentation in sync. Every code change ships with its matching doc updates in the **same commit**, gated by a mechanical drift-prevention grep before the task is declared done.

**REQUIRED BACKGROUND:** `superpowers:verification-before-completion` (evidence over assertion before declaring done).

**REQUIRED SUB-SKILL:** Step 5's optional sub-agent verification uses `superpowers:dispatching-parallel-agents`.

Project-specific paths, file-size thresholds, and plan-archive policies live in the project's `CLAUDE.md`, not here.

## The Atomicity Rule

A commit that changes a function signature without updating the doc that quotes it is a drift event waiting for a future audit. Reviewers (human or Claude) reading a code+doc commit verify both halves stay consistent in one pass; splitting them invites the doc half to be silently dropped. "Matching doc update" means: every doc that references a touched symbol either (a) still describes current behaviour or (b) has been edited in this commit. Step 1's grep is the mechanical check that proves (a) and surfaces what needs to become (b).

## Step 1 — Drift-Prevention Grep (mechanical, non-skippable)

Before declaring the task done, identify every symbol the change touches and grep for it across the project's docs directory.

- **Renamed / added / removed function or method**: `Grep` for the function name. Each hit must be verified or edited.
- **Changed function signature** (added / removed / renamed param, return type): `Grep` for the function name; check that doc snippets show the current signature.
- **Renamed / added / removed exported type, class, event, or globally-registered service** (e.g. classes, signals/events, autoloads, registered handlers, exported constants): `Grep` for the name. Registry-style mentions are the highest drift risk.
- **Renamed / moved file**: `Grep` for the old path or filename. The project's file registry (if any) is the most likely target; feature notes also cite paths.
- **Shipped task**: `Grep` for the task ID. Past-tense any "TASK-XYZ will ship Y" → "TASK-XYZ shipped Y", or drop the reference per the doc-rewrite discipline below.

**No hits** = symbol is undocumented. Fine for internals; suspect for a public API.

**Hits** = each one needs a quick read to confirm accuracy or an edit if it's stale. Frozen archive notes (e.g. `*-archived-*.md`) are exempt from the present-tense rewrite — they're historical records by design.

## Step 2 — Apply Doc Updates

Pick the cheapest tool for each job. Writes go through `Edit` (or `Write` for new files / full rewrites); reads through `Read` (with `offset` / `limit` for large files) or `Grep` for locating sections.

- **Frontmatter edits**: `Edit` on the specific YAML line — e.g. `last_updated: '<old>'` → `last_updated: '<new>'`. Each frontmatter field is unique within a note, so the `old_string` is naturally unambiguous. Batch parallel `Edit` calls for multi-file restamps.
- **Small note edits**: `Edit` with surgical `old_string` / `new_string`. Read first if the exact text isn't in your context. `Write` only for full rewrites or genuinely new files.
- **Large file** (multi-hundred-KB; project-specific list lives in `CLAUDE.md`): `Grep` to locate, `Read` with `offset` / `limit` for targeted lines, `Edit` for the change. Never read the whole file.
- **Batch over sequential**: parallel `Read` / `Edit` calls in one message when files are independent.
- **Don't re-read after edit**: `Edit` errors on `old_string` mismatch; a successful return means the change landed.
- **Search, don't browse**: `Grep` with file globs beats listing directories.

`Bash` is for `git`, read-only commands, and coordination — not file writes. Sandboxed environments may silently no-op `sed -i` and similar; reserve `Bash` for tasks `Edit` can't do.

## Step 3 — Restamp `last_updated`

After applying edits, restamp the `last_updated` frontmatter on **every modified note** with an `Edit` on the YAML line. Format follows the project's existing convention — read one neighbouring note if unsure (typically `'YYYY-MM-DD'`).

**Don't restamp notes you read but didn't change.** A restamp signals "content changed today", not "I looked at this". Future audits depend on the distinction.

## Step 4 — Stage + Draft Commit (don't commit yet)

1. **Stage the atomic set.** `git add` every file touched by this task — code + matching doc edits + implementation-plan / archive / instructions changes. One staging step, scoped to the work that just happened. Don't sweep up unrelated WIP.
2. **Inspect.** `git status` to confirm everything intended is staged and nothing extra. `git diff --cached --stat` for a quick what-changed summary.
3. **Draft a tight message — one line by default, two lines max.** Acceptable shapes: a single subject line; `subject -- rationale` on one line; or subject + one body line after a blank. **No multi-paragraph bodies.** Match the project's existing tone (run `git log -5 --oneline` if unsure); past-tense summary of what shipped. No Conventional Commits prefix unless the repo uses one.

## Step 5 — Present, Offer Verification, Await Approval

1. **Present.** Show the user the staged set + draft message.
2. **Offer the optional Explore sub-agent diff verification** before they commit:

> "Want me to dispatch an Explore sub-agent (Sonnet) to diff-walk this commit and cross-check against the docs you updated? It catches symbols the Step 1 grep missed — registry rows, exported fields hidden in refactors, public-API additions outside your mental model. Recommended for multi-file or cross-cutting changes; skip for single-symbol renames already verbally walked."

If the user says yes, dispatch:

```
Agent({
  subagent_type: "Explore",
  model: "sonnet",
  prompt: "Walk `git diff --cached` on touched code paths (or `git show HEAD --stat` if already committed). For each public symbol added/removed/renamed/signature-changed, cross-reference against the docs also touched in this commit. Report uncovered drift in <500 words. Skip archives (`*-archived-*.md`), audits, design scratchpads."
})
```

**Verify each finding against primary evidence yourself before acting** — read the cited code + doc lines directly. Sub-agents hallucinate severity, misread context, or cite wrong line numbers. Primary-source verification keeps the dispatch trustworthy.

If gaps found → fix inline (back to Step 2) → restamp affected notes (Step 3) → re-stage + re-present (Step 4) → re-offer this step. If clean, advance.

3. **Wait for explicit commit approval.** The user owns the `git commit` invocation. **Approval signals**: the words `commit`, `ship`, `go`, or a revised commit message the user wrote. **Not approval**: ambiguous affirmations like "looks good", "tie loose ends", "wrap it up", "finish", "let's go", or silence — these often mean "finish presenting the diff", not "execute the commit". When in doubt, ask: "commit with this message?"

The discipline is about atomicity, not autonomy. The skill handles the scaffolding; the user keeps editorial control.

## Doc Rewrite Discipline

Feature and component notes describe **current state in present tense**. They do not accrete task-by-task changelogs. When a task changes a system:

- **Rewrite the affected paragraph** to describe how the system works now. Don't append "TASK-XYZ added Y" / "Bug-fix Patch N corrected Z".
- **Drop date-stamped task references** from prose (`(TASK-F09, 2026-04-28)`). Git blame + plan archive carry the provenance.
- **Keep load-bearing architecture rules** that protect against re-introducing past bugs. Frame them as current-state invariants, not historical patches.
- **Don't add per-note History sections.** History lives in plan archives and `git log`.

If a future reader couldn't tell from the note alone what the system *does today* without reconstructing a sequence of tasks, the rewrite isn't done.

## Worked Example: Renaming + Re-Signing a Function

Code change: renamed `parse_csv_row()` → `parse_record()` and added an optional `delimiter` parameter in a parser module.

1. **Drift grep**: `Grep` for `parse_csv_row` across `docs/`. Three hits: `features/import.md`, `components/csv-parser.md`, `archive/import-v1-archived-2025-08.md`. Also `Grep` for `parse_record` to confirm no pre-existing collision.
2. **Triage hits**:
   - `features/import.md`: prose describes the import flow and quotes the function name + signature. **Rewrite** the paragraph to current state (`parse_record(row, delimiter=',')`).
   - `components/csv-parser.md`: API table row lists the function. **Edit the row** to the new name + signature.
   - `archive/import-v1-archived-2025-08.md`: archived deviation quotes the old name in code-span backticks as historical record. **Leave it** — frozen archive.
3. **Apply edits**: `Edit` on the two non-archive notes (parallel calls).
4. **Restamp**: `Edit` `last_updated` to today's date on the two edited notes. Archive untouched.
5. **Stage + draft + present**: `git add` parser module + the two doc edits. `git status` confirms the atomic set. Draft: *"Rename parse_csv_row to parse_record, add delimiter param; updated import.md + csv-parser.md to match."*
6. **Offer sub-agent verification**. If yes → dispatch Explore (Sonnet) → handle any gaps. If no → wait for explicit commit approval.

## Red Flags — STOP and Re-Check

Self-check signals you're rationalizing past the discipline:

- "Change is small, drift grep feels like overkill" → Step 1 is non-skippable. Small changes are when drift slips through.
- "I already mentally walked the docs" → Mental walks miss hits. Run the grep.
- "User said 'looks good', I'll commit" → Not approval. Wait for `commit`, `ship`, `go`, or a revised message.
- "I'll restamp every note I opened" → Restamp means changed, not viewed.
- "Just append a TASK-XYZ note at the bottom" → Notes describe current state, not history. Rewrite the prose.
- "Archive note has the old name, I'll fix that too" → Archives are frozen. Leave them.
- "Sub-agent verification is overkill, I'll skip the offer" → The user opts in or out; you don't decide for them on non-trivial changes.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Single-line change, no docs to update" | Public symbols → grep. Internal symbols → maybe; check anyway. |
| "Grep hits look fine on a skim" | Skim ≠ verify. Read each hit's surrounding context. |
| "User said 'wrap it up' = commit" | Ambiguous affirmations finish the *presentation*, not the *commit*. Ask. |
| "Sub-agent step is overkill, I'll skip" | The user opts in or out; *you* unilaterally skipping it for non-trivial changes is a discipline violation. |
| "Restamping read-only notes is harmless" | It corrupts the audit signal. Future audits will mistrust timestamps. |
| "I'll add a History section" | Git log + plan archives carry history. Note prose stays present-tense. |
| "Archive references old name; I'll fix it" | Archives are frozen historical records. Leave them. |

## Anti-Patterns

- **Skipping drift grep "because the change was small"** — exactly when drift slips through.
- **Trusting partial grep coverage** — `Grep` finds what you grep'd for, not what you forgot. Step 5's sub-agent verification is the backstop.
- **Relaying sub-agent findings as fact** — the agent cites code + doc lines; read both yourself before acting or surfacing the gap.

---
name: atomic-docs
description: >
  Keeps code and project documentation atomically in sync — same commit, no drift.
  Use this skill whenever a non-trivial code change is wrapping up (renamed/added/
  removed symbols, changed signatures, moved files, shipped tasks) — even if the
  user just says "ship it", "wrap up", "ready to commit", or "finish the task"
  without naming docs explicitly. Also activate on direct doc requests: "update
  docs", "sync docs", "fix doc drift", "rewrite the feature/component note for X".
  Skip for trivial formatting (whitespace, comment-only edits), work-in-progress
  code that doesn't compile yet, or pure code reads where nothing changed.
  Defines the drift-prevention grep, present-tense rewrite discipline,
  last_updated restamp rule, and code+doc atomicity rule. Project-specific paths,
  file sizes, and plan-archive policies live in the project's CLAUDE.md, not here.
---

# Atomic Docs — Code and Documentation in One Commit

This skill is the discipline source for keeping code and the project's documentation vault in sync. Every code change ships with its matching doc updates in the same commit, gated by a mechanical drift-prevention grep before you declare the task done.

## The Atomicity Rule

Code changes and their matching doc updates ship in the **same commit** (or same PR if commits are split for review).

A commit that changes a function signature without updating the doc that quotes that signature is a drift event waiting to be cleaned up by a future audit. A reviewer (human or Claude) reading a code+doc commit can verify both halves stay consistent in one pass; splitting them across commits invites the doc half to be silently dropped.

"Matching doc update" means: every doc that references a touched symbol either (a) still describes current behaviour or (b) has been edited in this commit. The drift-prevention grep below is the mechanical check that proves (a) and surfaces what needs to become (b).

## Step 1 — Drift-Prevention Grep (mechanical, non-skippable)

Before declaring a task done, identify every symbol the change touches and grep for it across the project's docs directory.

- For every **renamed / added / removed function or method**: `Grep` for the function name across the docs directory. Every hit is a doc location that must be verified against current code.
- For every **changed function signature** (added / removed / renamed param, changed return type): `Grep` for the function name; check that doc snippets show the current signature.
- For every **renamed / added / removed `class_name`, signal, or autoload**: `Grep` for the name. Autoload-list, signal-list, and resource-shape mentions are the highest drift risk.
- For every **renamed / moved file**: `Grep` for the old path or filename. The project's file registry (if it has one) is the most likely target but feature notes also cite paths.
- For every **shipped task**: `Grep` for the task ID in docs. Past-tense any "TASK-XYZ will ship Y" → "TASK-XYZ shipped Y" framings, OR drop the reference entirely per the doc rewrite discipline below.

**No hits** for a touched symbol = symbol is undocumented. Fine for internals, suspect for a public API — decide whether new docs are warranted.

**Hits** = each one needs a quick read to confirm it's still accurate, or an edit if it isn't. Frozen archive notes (e.g. `*-archived-*.md`) are exempt from the present-tense rewrite — they're historical records by design.

## Step 2 — Apply Doc Updates

Pick the cheapest tool for each job. Writes go through `Edit` (or `Write` for new files / full rewrites); reads go through `Read` (with `offset` / `limit` for large files) or `Grep` for locating sections. The docs vault is plain markdown on the filesystem — direct tool access is the canonical path.

- **Frontmatter edits** (timestamps, status flags, single-field swaps): `Edit` on the specific YAML line — e.g. `last_updated: '<old>'` → `last_updated: '<new>'`. Each frontmatter field is unique within a note, so the `old_string` is naturally unambiguous. Batch parallel `Edit` calls for multi-file restamps.
- **Small note edits**: `Edit` with surgical `old_string` / `new_string` pairs. Read first if you don't have the exact text in your context. `Write` only for full rewrites or genuinely new files.
- **Large file** (multi-hundred-KB; project-specific list lives in CLAUDE.md): `Grep` first to locate the relevant section, `Read` with `offset` / `limit` for the targeted lines, `Edit` for the change. Never read the whole file.
- **Batch over sequential**: parallel `Read` / `Edit` calls in one tool message when files are independent — cheaper than serial roundtrips.
- **Don't re-read after edit**: `Edit` errors on `old_string` mismatch; a successful return means the change landed. Re-reading wastes context.
- **Search, don't browse**: `Grep` with file globs beats listing directories + targeted reads for finding doc references.

`Bash` is for `git`, read-only commands, and coordination — not file writes. In sandboxed environments `sed -i` and similar can silently no-op without erroring; use `Edit` for write paths and reserve `Bash` for tasks `Edit` can't do.

Project-specific size thresholds and which exact files require the Grep+Read pattern live in the project's `CLAUDE.md`, not here.

## Step 3 — Restamp `last_updated`

After applying edits, restamp the `last_updated` frontmatter on **every modified note** (`update_frontmatter` with `merge=true`).

**Don't restamp notes you read but didn't change.** A restamp means "content changed today", not "I looked at this". If you opened a note to verify a grep hit was still accurate and made no edit, leave its timestamp alone.

Frontmatter date format follows the project's existing convention (read one neighbouring note to confirm if unsure — typically `'YYYY-MM-DD'`).

## Step 4 — Verify diff coverage with an Explore sub-agent

After Steps 1–3 but before staging, dispatch an `Agent (Explore)` sub-agent to walk the staged diff and cross-check against the docs you updated. Catches symbols the Step 1 grep missed because you didn't think to grep for them — registry entries, exported fields hidden in refactors, public-API additions outside your mental model of the change.

Brief shape (adapt to project):

> Walk `git diff --cached` on touched code paths (or `git show HEAD --stat` if already committed). For each public symbol added/removed/renamed/signature-changed (class_name, exported field, public function, signal, autoload, registry row), cross-reference against the docs also touched in this commit. Report uncovered drift in <500 words. Skip archives (`*-archived-*.md`), audits, design scratchpads.

The sub-agent absorbs the full diff into its own context and returns a focused list of gaps — keeping the diff out of yours. **Verify each finding against primary evidence yourself before acting**: read the cited code + doc lines directly, don't relay sub-agent claims as fact. Sub-agents can hallucinate severity or misread context; primary-source verification keeps the discipline honest.

If gaps found → fix inline (back to Step 2) → restamp affected notes (Step 3) → advance to Step 5. If clean, advance directly.

Skip this step only for mechanically trivial changes (single-symbol rename you walked through verbally, comment-only edit). For everything else, the sub-agent dispatch is cheap insurance against blind-spot drift.

## Step 5 — Compose the Commit (Stage + Draft, Wait for Approval)

After Steps 1–4, prepare the commit but stop short of pulling the trigger. The user owns the message + the `git commit` invocation.

1. **Stage the atomic set.** `git add` every file touched by this task — code + matching doc edits + implementation-plan / archive / instructions changes. One staging step, scoped to the work that just happened. Don't sweep up unrelated WIP.
2. **Inspect.** `git status` to confirm everything intended is staged and nothing extra. `git diff --cached --stat` for a quick what-changed summary.
3. **Draft a tight message — one line by default, two lines max.** Acceptable shapes: a single subject line; `subject -- rationale` on one line; or subject + one body line after a blank. **No multi-paragraph bodies.** Your draft is a starter for the user to approve or expand, not a finished essay. Match the project's existing tone (run `git log -5 --oneline` if unsure); past-tense summary of what shipped. No Conventional Commits prefix unless the repo uses one.
4. **Present, don't commit.** Show the user the staged set + draft message. Run `git commit -m "..."` (or HEREDOC for multi-line) only after explicit approval. **Approval signals**: the words `commit`, `ship`, `go`, or a revised commit message the user wrote. **Not approval**: ambiguous affirmations like "looks good", "tie loose ends", "wrap it up", "finish", "let's go", or silence after presenting — these often mean "finish presenting the diff", not "execute the commit". When in doubt, ask: "commit with this message?"

The discipline is about atomicity, not autonomy. The skill handles the scaffolding; the user keeps editorial control.

## Doc Rewrite Discipline

Feature and component notes describe **current state in present tense**. They do NOT accrete task-by-task changelogs. When a task changes a system:

- **Rewrite the affected paragraph** to describe how the system works now. Don't append "TASK-XYZ added Y" / "Bug-fix Patch N corrected Z" / etc.
- **Drop date-stamped task references** from prose (`(TASK-F09, 2026-04-28)`). Git blame + the implementation-plan archive carry the provenance.
- **Keep load-bearing architecture rules** that protect against re-introducing past bugs (e.g. "tick_state must NOT clear last_summon_events"). Frame them as current-state invariants, not historical patches.
- **Don't add per-note History sections.** History lives in plan archives and `git log`.

If a future reader couldn't tell from the note alone what the system *does today* without reconstructing a sequence of tasks, the rewrite isn't done.

## Worked Example: Renaming a Function

Code change: renamed `try_charge_and_plant()` → `commit_planting()` in a system script.

1. **Drift grep**: `Grep` for `try_charge_and_plant` across `docs/`. Three hits: `features/farm.md`, `components/core-systems/farm-system.md`, `guides/implementation-plan-archived-m1.md`.
2. **Triage hits**:
   - `features/farm.md`: paragraph describes the planting flow and quotes the function name. **Rewrite** to use `commit_planting()`.
   - `components/core-systems/farm-system.md`: API table lists the function. **Edit the row** to the new name.
   - `guides/implementation-plan-archived-m1.md`: an archived deviation bullet from a shipped TASK references the old name in code-span backticks as historical record. **Leave it** — frozen archive, present-tense rule doesn't apply to history.
3. **Apply edits**: `patch_note` on the two component/feature notes; ignore the archive.
4. **Restamp**: `update_frontmatter` with `merge=true` on the two edited notes (today's date). Don't touch the archive's `last_updated` (it's frozen).
5. **Verify diff coverage**: dispatch an `Agent (Explore)` to walk the staged code diff and cross-check against the two doc edits. For a single-symbol rename like this, the agent reports "no gaps found" — Step 1's grep already covered the surface. Larger refactors typically surface 1–3 gaps here (registry rows, signature tweaks, exported fields the grep didn't think to look for); fix inline + restamp, then continue.
6. **Stage + draft commit, wait for approval.** `git add` the script change + the two doc edits + (if applicable) the implementation-plan task-table row. `git status` to verify the atomic set. Draft message: e.g. *"Renamed try_charge_and_plant to commit_planting; updated farm.md + farm-system.md to match."* Present staged set + draft to user; run `git commit` only on their approval (modified or as-is).

## Anti-Patterns

- **Skipping the drift grep "because the change was small".** That's exactly when drift slips through — the small changes are the ones not worth a careful read but still touching documented symbols.
- **Trusting that grep coverage was complete.** `Grep` finds doc references to symbols you grep'd for; it doesn't catch symbols you forgot to grep for (a new registry row, an exported field tucked into a refactor, a helper added alongside the main change). The Step 4 sub-agent verification is the backstop. Skipping it leaves blind-spot drift that surfaces in audits weeks later.
- **Relaying sub-agent findings as fact.** When the Step 4 agent reports a gap, it cites a code line and a doc line. Read both yourself before applying a fix or surfacing the gap to the user — sub-agents misread context, mis-rank severity, or hallucinate line numbers. The primary-source verification is what makes the sub-agent dispatch trustworthy.

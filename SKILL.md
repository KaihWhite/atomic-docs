---
name: atomic-docs
description: >
  Keeps code and project documentation atomically in sync — same commit, no drift.
  Use after any non-trivial code change (renamed/added/removed symbols, changed
  signatures, moved files, shipped tasks) to drift-check and update the project's
  doc vault before declaring the task done. Also use when the user asks to update
  docs, sync docs, fix doc drift, or rewrite a feature/component note. Defines
  the drift-prevention grep, present-tense rewrite discipline, last_updated
  restamp rule, and code+doc atomicity rule. Project-specific paths, file sizes,
  and plan-archive policies live in the project's CLAUDE.md, not here. For
  Obsidian MCP tool selection details, see the `obsidian` skill.
---

# Atomic Docs — Code and Documentation in One Commit

This skill is the discipline source for keeping code and the project's documentation vault in sync. Every code change ships with its matching doc updates in the same commit, gated by a mechanical drift-prevention grep before you declare the task done.

## When to Use

**Trigger after any of these code changes:**

- Renamed, added, or removed function, method, `class_name`, signal, or autoload
- Changed signature (param added/removed/renamed, return type changed)
- Renamed or moved file (path or filename change)
- Shipped task (closing a planned work item)

**Also trigger when the user says:**

- "update docs", "sync docs", "atomic doc check", "doc drift", "fix the docs"
- "rewrite the feature note", "update the component note for X"

**Skip for:**

- Trivial formatting (whitespace, comment-only edits)
- Work-in-progress that hasn't compiled yet — wait until the change is real
- Pure code reads (you didn't change anything)

**Not for:** project init, vault structure setup, or first-time doc bootstrap. Those are one-shot tasks; the archived `doctrack` skill at `~/.claude/skills-archived/doctrack/SKILL.md` has the heavy bootstrap flow if you ever need it.

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

Pick the cheapest tool for each job:

- **Metadata only** (timestamps, status, existence checks): always use Obsidian MCP — `get_frontmatter`, `get_notes_info`, `update_frontmatter` (with `merge=true`), `search_notes`. These skip content entirely.
- **Small note** (rough rule: under ~10 KB / ~200 lines): `mcp__obsidian__patch_note` for surgical edits; `write_note` with frontmatter inline for full rewrites (one call, not write + update_frontmatter).
- **Large file**: `Grep` to locate the relevant section, `Read` with `offset`/`limit` for the targeted lines, `Edit` with old/new strings. Don't load whole.
- **Batch over sequential**: `read_multiple_notes` (cap 10) instead of N `read_note` calls; batch `get_notes_info` for multi-path existence checks.
- **Don't re-read**: if a note loaded this session hasn't changed externally, reference cached content. `Edit`/`patch_note` error on failure — no need to reload to verify success.
- **Search, don't browse**: `search_notes` with `searchFrontmatter=true` beats `list_directory` + batch reads for finding relevant docs.

For Obsidian MCP gotchas (multi-match defaults, frontmatter matching, confirmation requirements, error recovery), see the `obsidian` skill.

Project-specific size thresholds and which exact files require the Grep+Read pattern live in the project's `CLAUDE.md`, not here.

## Step 3 — Restamp `last_updated`

After applying edits, restamp the `last_updated` frontmatter on **every modified note** (`update_frontmatter` with `merge=true`).

**Don't restamp notes you read but didn't change.** A restamp means "content changed today", not "I looked at this". If you opened a note to verify a grep hit was still accurate and made no edit, leave its timestamp alone.

Frontmatter date format follows the project's existing convention (read one neighbouring note to confirm if unsure — typically `'YYYY-MM-DD'`).

## Step 4 — Compose the Commit (Stage + Draft, Wait for Approval)

After Steps 1–3, prepare the commit but stop short of pulling the trigger. The user owns the message + the `git commit` invocation.

1. **Stage the atomic set.** `git add` every file touched by this task — code + matching doc edits + implementation-plan / archive / instructions changes. One staging step, scoped to the work that just happened. Don't sweep up unrelated WIP.
2. **Inspect.** `git status` to confirm everything intended is staged and nothing extra. `git diff --cached --stat` for a quick what-changed summary.
3. **Draft a message.** Match the project's existing tone (run `git log -5 --oneline` if unsure of the style). Default to a single-line past-tense summary of what shipped + optional rationale after a `--` separator. No Conventional Commits prefix unless the repo uses one.
4. **Present, don't commit.** Show the user the staged set + draft message. They approve as-is, modify, or override. Run `git commit -m "..."` (or HEREDOC for multi-line) only after explicit approval — `commit`, `ship`, `go`, or a revised message all count.

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
5. **Stage + draft commit, wait for approval.** `git add` the script change + the two doc edits + (if applicable) the implementation-plan task-table row. `git status` to verify the atomic set. Draft message: e.g. *"Renamed try_charge_and_plant to commit_planting; updated farm.md + farm-system.md to match."* Present staged set + draft to user; run `git commit` only on their approval (modified or as-is).

## Anti-Patterns

- **Splitting code change and doc update into separate commits.** Defeats the atomicity rule. Either rebase before push or include both halves before committing.
- **Restamping `last_updated` on notes you only read.** Pollutes the change-history signal — git diff and frontmatter diverge.
- **Adding "Updated for TASK-XYZ" comments to feature notes.** Use git history; doc prose stays present-tense.
- **Loading large archive files whole when offset/limit Read works.** Burns context for no reason; Grep + targeted Read is the established pattern.
- **Skipping the drift grep "because the change was small".** That's exactly when drift slips through — the small changes are the ones not worth a careful read but still touching documented symbols.
- **Auto-committing without user approval.** The skill prepares the commit (stage + draft message); the user pulls the trigger. Per-task review judgment + commit-message authorship belong to them.

## See Also

- The project's `CLAUDE.md` carries the project-specific bits: vault path, file paths and sizes, implementation-plan archive/deviations workflow, current milestone state, where index notes (e.g. `_project.md`, `_file_registry.md`) live and when to load each.
- The `obsidian` skill carries Obsidian MCP tool details, gotchas, error recovery, and routing between MCP / Obsidian CLI/app / git.
- For first-time project init or vault structure setup, the archived `doctrack` skill at `~/.claude/skills-archived/doctrack/SKILL.md` has the heavy bootstrap flow. It's intentionally not in the active skill list — load it explicitly via `Read` only when bootstrapping a new project.

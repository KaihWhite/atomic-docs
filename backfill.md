# Backfill — Seeding Live Docs in an Existing Project

One-time (or gap-filling) pass that writes `docs/reference/` docs for features that have none, and seeds `state.md` / `worklog.md` if absent. Templates and paths come from `SKILL.md` § The Live Docs; this file only covers the backfill process.

**REQUIRED SUB-SKILL:** `superpowers:dispatching-parallel-agents` for Step 2.

## Step 1 — Feature Inventory (stop for approval)

1. **Find what's already covered.** `Grep` `docs/reference/*.md` for `sources:` entries. Covered files are out of scope.
2. **Find features.** `Glob` the code tree for module directories, entry points, and public-interface declarations (classes, services, autoloads, registered handlers). Apply `SKILL.md`'s boundary: one doc per feature that owns its own files or public interface; helpers fold into their parent.
3. **Merge in known gaps.** If a recent audit report lists uncovered features, include them.
4. **Present the inventory** and stop until the user approves or edits it:

| Feature | Doc path | `sources:` | Purpose (one line) |
|---------|----------|------------|--------------------|
| Importer | `reference/importer.md` | `src/importer/` | Parses CSV/TSV uploads into records |

Feature boundaries are the expensive call to get wrong — once docs exist, re-cutting them means rewriting several. Don't dispatch until the table is approved.

## Step 2 — Dispatch Writers in Parallel

One `general-purpose` sub-agent per feature (group tiny features in one agent). All calls in **one message**, in waves of ~8.

```
Agent({
  subagent_type: "general-purpose",
  description: "Write reference doc: <Feature>",
  prompt: "Write `<doc path>` documenting the <Feature> feature.
    sources: <list>
    Template (fill every section; frontmatter last_updated: '<today>' and the sources list above):
    <paste the reference template from SKILL.md>
    Rules: read only the sources, plus just enough of direct callers to describe Interfaces.
    Present tense, current behaviour only — no history. Write only this one file. No git commands.
    Return: (1) a 3-line summary, (2) other features this doc mentions or depends on."
})
```

## Step 3 — Consolidate (main session)

For every returned doc:

- **Shape check** — frontmatter has `last_updated` + `sources:`; all six template sections present.
- **Spot-check** — verify one Key Files & Symbols row against the code. Sub-agents hallucinate signatures; a wrong row means read the whole doc against its sources.
- **Related links** — fill each doc's Related section from the dependency lists the agents returned; sub-agents can't see each other's docs.

## Step 4 — Seed State + Worklog

- **`state.md` absent** → `Write` it from the template; Status summarizes the inventory (what exists, overall phase). Leave unknown sections empty rather than guessing.
- **`worklog.md`** → create if absent, then append one entry: **Done** "Backfilled N reference docs"; **Decisions** records non-obvious boundary calls from Step 1.

## Step 5 — Stage + Present

Follow `SKILL.md` Steps 5–6. The whole backfill is **one commit**; the user approves it like any other.

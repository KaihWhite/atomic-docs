# Stop Hook — Pickup Notes

**Status:** disabled in bone-orchard (`.claude/settings.json`, removed 2026-05-05). Skill is firing reliably enough on its own via description-trigger + project memory; the hook is parked until a clean re-design lands here.

This doc captures everything we learned while debugging the previous hook so the next pass doesn't repeat the same mistakes. Anyone setting up the hook from the README's advice ("ask Claude to set up a Stop hook with a state check") should read this first.

## What was tried (and broke)

The hook lived in the project's `.claude/settings.json` and looked like this:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "shell": "bash",
            "command": "git status --porcelain 2>/dev/null | grep -qE '^.. (data|scenes|scripts|tests|ui)/|^.. project\\.godot$| -> (data|scenes|scripts|tests|ui)/| -> project\\.godot$' && echo '{\"hookSpecificOutput\":{\"hookEventName\":\"Stop\",\"additionalContext\":\"Code changes detected... invoke Skill -> atomic-docs...\"}}'"
          }
        ]
      }
    ]
  }
}
```

Two failure modes were observed every turn end:

| Git state | Failure | User-visible message |
|---|---|---|
| Uncommitted code under tracked dirs | `echo` runs → emits wrong-schema JSON | `Hook JSON output validation failed — (root): Invalid input` |
| No matching uncommitted code | `grep -q` exits 1 → `&&` short-circuits → pipeline exits 1 | `Stop hook error: Failed with non-blocking status code: No stderr output` |

So the hook had effectively been a **no-op-with-error-spam** since installation — it never actually delivered context to Claude.

## Bug 1 — wrong JSON shape for Stop

`{"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": "..."}}` is **not valid for Stop hooks**.

`additionalContext` is only accepted on hook events that inject context into a future Claude turn:
- `SessionStart`
- `UserPromptSubmit`
- `UserPromptExpansion`
- `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PostToolBatch`
- `SubagentStart`
- `Setup`

Stop fires *as Claude is ending a turn* — there's no future turn to inject context into. So Stop's accepted top-level fields are different:

| Field | Effect |
|---|---|
| `decision: "block"` + `reason: "..."` | Prevents stop; `reason` is fed back to Claude as instruction |
| `continue: false` + `stopReason: "..."` | Halts processing; message shown to user (not Claude) |
| `systemMessage: "..."` | Warning shown to **user**, not Claude |
| `suppressOutput: true/false` | Omits stdout from debug log |

Only `decision: block` actually routes a message back to Claude. The rest are user-facing or admin.

## Bug 2 — non-zero exit on no-match

```bash
git status --porcelain | grep -qE 'PATTERN' && echo 'JSON'
```

When `grep -q` finds nothing, it exits 1, the `&&` skips `echo`, and the pipeline as a whole exits 1. Claude Code treats any non-zero hook exit as an error. (Exit code `2` is the documented "blocking" code that gets fed back to Claude; everything else is "non-blocking error" and shown to the user.)

Fix: ensure exit 0 on no-match. Two equivalent shapes:

```bash
# Option A: if/then/fi
if git status --porcelain 2>/dev/null | grep -qE 'PATTERN'; then echo 'JSON'; fi

# Option B: explicit fallthrough
git status --porcelain 2>/dev/null | grep -qE 'PATTERN' && echo 'JSON' || true
```

`if/fi` is cleaner because the trailing `|| true` swallows real errors too.

## Bug 3 (lurking) — blocking semantics don't match intent

Even with bugs 1 and 2 fixed, the *behavioral* model is wrong.

The original `additionalContext` shape was meant as a **soft hint** — Claude sees "you should consider atomic-docs" but isn't forced to act. The only Stop-side mechanism that actually messages Claude is `decision: block`, which is a **hard block**: Claude cannot end the turn until it addresses the reason.

Replacing the soft hint with a hard block introduces these failure modes:

1. **Extra turn after staging.** `atomic-docs` stops at *staged + drafted, user owns commit*. After Claude stages, `git status --porcelain` still shows the entries (now with `M  ` instead of ` M `). Hook re-fires → Claude must output something more before another stop attempt → "I've staged X, awaiting your commit approval" → stop attempt → re-blocks. Without further mitigation, Claude can be stuck in a brief loop until it generates output the hook is satisfied with (which it never is, until commit happens).

2. **No "WIP, hush" escape hatch.** If you want to stop mid-task to playtest before committing, every Stop in that thread re-blocks. There's no per-turn opt-out short of committing or reverting.

3. **Pathological re-runs.** If Claude doesn't recognize the second/third block as "already done atomic-docs this turn," it might re-run drift-grep each block. Rare but possible.

## What to design for next time

The goal is "nudge Claude to run atomic-docs when there's uncommitted code that documentation should follow," **without** the blocking-loop pathology. Three viable directions, in rough order of preference:

### 1. Stage-aware regex + `decision: block` (probably best)

Block only when there are **unstaged** game-side changes. Once Claude stages via atomic-docs, the hook quiets — user can commit at leisure.

`git status --porcelain` format is `XY filename` where X = index status, Y = working tree status:
- ` M file` — modified, unstaged → should fire
- `M  file` — modified, fully staged → should NOT fire
- `MM file` — staged AND further unstaged work → should fire
- `?? file` — untracked → should fire

Regex sketch (needs validation): match when Y is non-space-non-dot (working-tree side has work), restricted to game dirs. Roughly `^.[MD?]\s(data|scenes|scripts|tests|ui)/`.

This eliminates the extra-turn loop in the happy path — atomic-docs stages, hook stops complaining, user commits when ready.

### 2. `systemMessage` instead of `decision: block`

Show the warning to the user, not Claude. Closest to the original "soft nudge" intent. Downside: user has to manually tell Claude "run atomic-docs" — defeats the automation goal.

Reasonable fallback if (1) feels too clever.

### 3. Move to `UserPromptSubmit` event

That event *does* support `additionalContext` (genuine soft injection into the next Claude turn). Downside: fires on every prompt submission, not just at end-of-work. Would need state-check logic to only inject when relevant (e.g., uncommitted game-side changes since session start). More complex than (1).

## Re-enabling checklist

When picking this up:

1. Pick a direction (probably #1 above).
2. Write the hook command and **test it standalone** before wiring into Claude Code:
   - `bash -c '<command>'; echo "EXIT=$?"` — verify exit 0 in both states (match and no-match).
   - Verify the JSON output (when it fires) is valid against the chosen Stop schema field.
3. Install in `.claude/settings.json` and watch a few real turn-ends:
   - No errors on idle turns? Good (bug 2 fixed).
   - Triggers correctly when game-side code is dirty? Good (regex correct).
   - Doesn't loop after atomic-docs stages? Good (bug 3 mitigated).
4. Update the `README.md` in this repo — current advice ("ask Claude to set up a Stop hook") is what produced the broken hook. Replace with a pointer to a known-good template, or to this doc.

## Reference — Claude Code hook docs

- https://code.claude.com/docs/en/hooks.md — top-level events and JSON shapes
- Key insight: per-event field validation is strict. `additionalContext` outside its supported events is rejected at the root.

## Related context (bone-orchard specific, not part of this skill)

The bone-orchard project has these reinforcing triggers for atomic-docs even without the hook:
- Skill `description` frontmatter explicitly names "after non-trivial code change… before declaring task done."
- `CLAUDE.md` references the doc-discipline workflow.
- User memory `feedback_task_completion_workflow.md` reminds Claude to apply atomic-docs after each implementation-plan task.

Empirically these catch >90% of the cases the hook was meant to backstop. Worth measuring the actual gap (drift-creep in feature notes, stale `last_updated` on edited notes) before re-adding the hook.

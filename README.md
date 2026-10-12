I reccomend referencing this skill in your CLAUDE.md by mentioning it should trigger on every code change to keep atomicity and minimize drift.

The skill maintains three live docs — `docs/state.md`, `docs/worklog.md`, and `docs/reference/` — but only fires at wrap-up. To have sessions start from them, add something like this to your CLAUDE.md:

```markdown
## Project context
- At session start, read `docs/state.md` and the last few entries of `docs/worklog.md`.
- Before working on a feature, read its doc in `docs/reference/` (match by name or `sources:`).
- After every non-trivial code change, use the atomic-docs skill.
```

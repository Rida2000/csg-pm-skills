# Templates

Use these verbatim. Do not invent a different layout — the structure is load-bearing (the manifest
is the parallel-track contract + update state). Locally the bundle keeps **two separate files**:
`PRD.md` (human-facing) and `IMPLEMENTATION.md` (the per-section, environment-agnostic
implementation prompts). They stay separate on disk; the published **Lark Docx merges them per
section** (see `reference.md`), placing each section's prompt as a **copyable code block** under that
section's heading.

## `manifest.json`

```jsonc
{
  "feature": "settings-theme-toggle",
  "mode": "branch-diff",                 // branch-diff | standalone
  "scope": {
    "strategy": "fork-point",            // fork-point | commit-range | since-ref | files | whole-project
    "base": "origin/main",               // also record the resolved fork-point sha; null when N/A
    "range": null,                       // e.g. "<A>..<B>" for commit-range
    "paths": []                          // for strategy=files
  },
  "sessions": ["<transcript path or id>", "..."],   // may span multiple parallel sessions
  "branch": "settings-theme-prototype",
  "date": "2026-06-03",
  "designer": "gaoshihan",
  "bundle_path": "prd/2026-06-03-settings-theme-toggle/",
  "lark": {
    "doc_token": null,                   // filled on first publish
    "url": null,
    "block_map": {}                      // { "C1": ["blk1","blk2"], ... } section → Lark block IDs
  },
  "changes": [
    {
      "id": "C1",
      "order": 1,
      "depends_on": [],                  // e.g. C2 → ["C1"]
      "title": "Build the 3-state ThemeToggle component",
      "intent": "auto / light / dark as a segmented toggle, not a <select>",
      "why": "dropdown hid the options; toggle shows all three at a glance",
      "why_source": "transcript:<session A>",   // transcript:<id> | commit | interview | inferred
      "files": ["components/ThemeToggle.tsx", "app/settings/page.tsx"],
      "marks": [
        {
          "n": 1,                        // global callout number → legend ①
          "route": "/settings",
          "target": "the theme <select> in the Appearance card",
          "selector_hint": "[data-testid=theme-select]",   // best-effort; may be null
          "container_hint": "[data-testid=appearance-card]",
          "framing": "element+context",  // full-page | element | element+context | before-after | none
          "callout": "auto / light / dark toggle",
          "screenshot": "screenshots/C1-settings.png"
        }
      ],
      "acceptance_seed": ["All three options visible without opening a menu"]
    }
  ]
}
```

## `PRD.md` (human-facing; sections ordered by implementation sequence)

`PRD.md` is **human-only** — what / why / acceptance + screenshots. It does **not** embed the
implementation prompt; each section ends with a one-line **pointer** to the matching
`IMPLEMENTATION.md` block. The copy-pasteable prompt is merged in only when publishing to Lark (per
section, as a code block — see `reference.md`).

```markdown
# PRD — <feature>
**Branch:** <branch> · **Base:** <base @ sha> · **Designer:** <name> · **Date:** <date>
**Status:** Ready for dev

# Summary
- <what this change is, at a glance>
- <the user-facing outcome / why it matters>
- Prototyped — reproduce **production-quality** per each section's implementation prompt
  (in `IMPLEMENTATION.md`, merged under the section in the Lark doc).

---
## C1 — <title>            [implement first · no deps]
![C1](screenshots/C1-settings.png)
**Legend:** ① <callout>

**What changed.** <plain language>
**Why.** <rationale> *(source: <why_source>)*
**Acceptance criteria**
- [ ] …

_Implementation prompt → `IMPLEMENTATION.md` §C1 (merged into the Lark doc under this section as a copyable code block)._

## C2 — <title>            [depends on C1]
![C2](screenshots/C2-settings.png)
**Legend:** ② <callout>
…
```

> The PRD section heading keeps the stable `C1`/`C2` id (it's the join key across the manifest,
> `depends_on`, screenshot filenames, and the Lark `block_map`; it stays fixed across reorders so
> in-place updates don't break).

## `IMPLEMENTATION.md` (per-section, ordered; **environment-agnostic** — no SSH/IP/port/branch rules)

```markdown
## C1 — <title>            [implement first · no deps]

**Goal:** <what to build, behavior-level>

**Exact prototype code (reuse as-is if convenient):**
- Prototype branch `<branch>` @ `<sha>`  (repo: <origin url>)
- Files: `<files>`
- If you have repo access: `git show <sha>:<file>`

**Reference diff (reproduce the behavior in your project's conventions, or lift the code above):**
\`\`\`diff
<fork-point diff scoped to this section's files>
\`\`\`
<!-- standalone mode: paste the prototype files themselves instead of a diff -->

**Acceptance criteria (Definition of Done):**
- [ ] …

**Verify:** in your dev environment, open the <screen> and match it against
screenshots/C1-*.png (callout ①).
```

Rules:
- No "Why it matters" here — rationale lives only in `PRD.md`.
- The inline diff + acceptance + screenshot must be enough to implement with **no** access to the
  prototype repo; the git refs are a convenience for those who have access.
- This per-section block is exactly what the Lark publish step embeds (as a **code block**) under
  the matching PRD section — keep it self-contained and copy-pasteable.

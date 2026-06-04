# Templates

Use these verbatim. Do not invent a different layout — the structure is load-bearing (the manifest
is the parallel-track contract + update state). Locally the bundle keeps **two separate files**:
`PRD.md` (human-facing) and `IMPLEMENTATION.md` (the per-section, environment-agnostic
implementation prompts). They stay separate on disk; the published **Lark Docx merges them per
section** (see `reference.md`), placing each section's **entire** prompt as a single copyable code
block under that section's heading.

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
      // acceptance_seed items are BEHAVIOURAL — what a person observes in the running product.
      // No compile checks, no class name assertions. These become the "Looks right when" list.
    }
  ]
}
```

## `PRD.md` (human-facing; sections ordered by implementation sequence)

`PRD.md` is **human-only** — what a person sees or experiences, why the decision was made, and
what "done" looks like from a product perspective. It does **not** embed implementation details or
the implementation prompt; those belong in `IMPLEMENTATION.md`. The copy-pasteable prompt is merged
in only when publishing to Lark (per section, as a code block — see `reference.md`).

**Language rule:** no component names, CSS classes, TypeScript types, i18n keys, API function names,
or file paths in `PRD.md`. If you find yourself writing a class name or function call, stop — move
it to `IMPLEMENTATION.md`.

**Screenshot rule:** every section gets at least one screenshot. A section can have multiple marks
(①②③ globally numbered) — use as many as needed to show all distinct visible effects. Only omit
screenshots for product-invisible changes (build config, server-only migration, CI scripts).

**"Looks right when" rule:** items are observable by a person in the running product — no compile
checks, no CSS class assertions. Could a PM read this without opening the codebase? If not, strip it.

```markdown
# PRD — <feature>
**Branch:** <branch> · **Base:** <base @ sha> · **Designer:** <name> · **Date:** <date>
**Status:** Ready for dev

# Summary
- <what this change is, at a glance — plain product terms>
- <the user-facing outcome / why it matters>
- Prototyped — reproduce **production-quality** per each section's implementation prompt
  (in `IMPLEMENTATION.md`, merged under the section in the Lark doc).

---
## C1 — <title>            [implement first · no deps]

<!-- Even "non-visual" code changes (i18n, type scaffolding) often have a visible result.
     Show it. framing: none only if nothing appears anywhere in the running product. -->
![C1](screenshots/C1-sidebar.png)
**Legend:** ① <what the callout marks, in plain words>

**What changed.** <what a person sees or experiences — no code names, no CSS, no types>
**Why.** <product rationale, one or two sentences> *(source: <why_source>)*
**Looks right when**
- [ ] <something verifiable by looking at or clicking the running product>
- [ ] <another observable outcome>

_Implementation prompt → `IMPLEMENTATION.md` §C1 (merged into the Lark doc under this section as a copyable code block)._

---
## C2 — <title>            [depends on C1]

<!-- Example of a section with multiple marks showing distinct areas of change. -->
![C2-a](screenshots/C2-content.png) ![C2-b](screenshots/C2-sidebar.png)
**Legend:** ② <callout for first mark>   ③ <callout for second mark>

**What changed.** <plain product description covering both marks>
**Why.** <rationale> *(source: <why_source>)*
**Looks right when**
- [ ] <observable outcome relating to first mark>
- [ ] <observable outcome relating to second mark>

_Implementation prompt → `IMPLEMENTATION.md` §C2 (merged into the Lark doc under this section as a copyable code block)._
```

> The PRD section heading keeps the stable `C1`/`C2` id (it's the join key across the manifest,
> `depends_on`, screenshot filenames, and the Lark `block_map`; it stays fixed across reorders so
> in-place updates don't break).

## `IMPLEMENTATION.md` (per-section, ordered; **environment-agnostic** — no SSH/IP/port/branch rules)

Each section's prompt is **one code block** — Goal, code refs, diff, acceptance, and verify all
inside a single fence, with the diff as plain text **inside** it (not its own nested fence). The
Lark publish step drops this whole block in as a single copyable code block under the section, so a
dev copies the entire prompt in one action.

````markdown
## C1 — <title>            [implement first · no deps]

```text
Goal: <what to build, behavior-level>

Exact prototype code (reuse as-is if convenient):
- Prototype branch <branch> @ <sha>   (repo: <origin url>)
- Files: <files>
- With repo access: git show <sha>:<file>

Reference diff (reproduce in your project's conventions, or lift the code above):
<fork-point diff scoped to this section's files>
(standalone mode: paste the prototype files themselves instead of a diff)

Acceptance criteria (Definition of Done):
- [ ] <criterion>

Verify: open <screen> and match it against screenshots/C1-*.png (callout ①).
```
````

Rules:
- No "Why it matters" here — rationale lives only in `PRD.md`.
- The diff + acceptance + screenshot reference must be enough to implement with **no** access to the
  prototype repo; the git refs are a convenience for those who have access.
- **One code block per section, no nested fences.** Everything from Goal to Verify lives in that
  single block (the diff is plain text inside it). The Lark publish step embeds the **entire** block
  as one code block under the matching PRD section — never just the diff.

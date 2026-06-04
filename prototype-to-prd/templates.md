# Templates

Use these verbatim. Do not invent a different layout — the structure is load-bearing (the manifest
is the parallel-track contract + update state). Locally the bundle keeps **two separate files**:
`PRD.md` (human-facing) and `IMPLEMENTATION.md` (the per-section, environment-agnostic
implementation prompts). They stay separate on disk; the published **Lark/Feishu Docx merges them
per section**. Both `PRD.md` and the Lark doc follow the **canonical document structure** below.

## Canonical document structure (PRD.md AND the Lark doc)

One standard format. Heading levels are exact — they drive Feishu's outline/folding and must not be
flattened into bold-inline labels.

```
H1   PRD — <feature>                         ← the umbrella title over ALL sections (C1…Cn)
     Branch · Base @ sha · Designer · Date · Status   ← metadata line, directly under H1
H2   Summary                                 ← bullets + (reading-order / prototype-caveat / callout) notes
H2   C1 — <title>   [build: …]               ← one per feature
       image(s)                              ← PRD: ![img] + Legend line · Lark: image block, legend = caption
H3     What changed                          ← prose (NOT a bold inline label)
H3     Why                                   ← prose  (source: …)
H3     Looks right when                      ← checklist
H3     Implementation prompt                 ← PRD: pointer to IMPLEMENTATION.md · Lark: ⚠ disclaimer + code block
H2   C2 — <title>   [build: …]
       …
```

Non-negotiable: the four per-section parts (**What changed / Why / Looks right when /
Implementation prompt**) are **parallel H3 sub-sections**, never `**bold**:` labels packed into one
paragraph. There is exactly **one H1** (the title) covering every feature.

### Bilingual labels (use idiomatic labels — NEVER literal word-for-word translation)

| Element | English | 中文 |
|---|---|---|
| Title | `PRD — <feature>` | `PRD — <功能>` |
| Metadata | Branch / Base / Designer / Date / Status | 分支 / 基线 / 设计 / 日期 / 状态 |
| Overview | Summary | 概述 |
| Sub-section | What changed | 改动内容 |
| Sub-section | Why | 设计原因 |
| Sub-section | Looks right when | 验收要点  · *never* `看起来正确当` |
| Sub-section | Implementation prompt | 实现提示 |
| Disclaimer | ⚠️ Auto-generated — review and adapt before use | ⚠️ 本提示由 AI 自动生成，使用前请核对并按需调整 |

**Language rule:** the doc language is resolved in Phase 0 as `doc_language` and **defaults to
English**; produce Chinese (or another language) only when the operator requests it. Whatever the
language, write **idiomatic** prose and use the glossary labels above — never translate an English
label literally (the `看起来正确当` failure). Metadata (branch/base/date) is **always present**, in
both languages.

### Section ordering — decoupled (two orders, same sections)

The same sections (same stable `C`-ids) appear in both files, but each file sequences them for its
reader:

- **`prd_order`** — the **PM/narrative** order, used by `PRD.md` **and the Lark doc**: the containing
  screen/flow first, then the dialogs/popups discovered *inside* it, then shell/wordmark. This is how
  a designer reviews the work ("here's the Billing page → and the buy-credits dialog it opens").
- **`impl_order`** — the **build** order, used by `IMPLEMENTATION.md`: dependencies first (respects
  `depends_on`), so a developer implements top-to-bottom.
- **`depends_on`** — the build-prerequisite graph. In the narrative-ordered PRD each heading shows a
  short `[build: …]` hint (e.g. `[build: needs C4, C5 first]`) so a reader still knows the build order.

## `manifest.json`

```jsonc
{
  "feature": "settings-billing-usage",
  "mode": "branch-diff",                 // branch-diff | standalone
  "doc_language": "en",                  // resolved in Phase 0; "en" (default) | "zh" | ...
  "scope": {
    "strategy": "fork-point",            // fork-point | commit-range | since-ref | files | whole-project
    "base": "origin/main",               // also record the resolved fork-point sha; null when N/A
    "range": null,                       // e.g. "<A>..<B>" for commit-range
    "paths": []                          // for strategy=files
  },
  "sessions": ["<transcript path or id>", "..."],   // may span multiple parallel sessions
  "branch": "v0.8-prototype",
  "date": "2026-06-04",
  "designer": "gaoshihan",
  "bundle_path": "prd/2026-06-04-settings-billing-usage/",
  "lark": {
    "doc_token": null,                   // filled on first publish
    "url": null,
    "doc_language": "en",                // language the doc was published in
    "source_markdown": "feishu-doc.md",  // the assembled doc source; update = recreate from this
    "block_map": {}                      // {} for markdown-import publishes (see reference.md)
  },
  "changes": [
    {
      "id": "C1",
      "prd_order": 1,                    // narrative position (PRD.md + Lark doc)
      "impl_order": 2,                   // build position (IMPLEMENTATION.md)
      "depends_on": ["C2"],              // build prerequisites — what must be DONE before this one
      "title": "Settings screen with the new section",
      "intent": "the screen a user lands on; opens the dialog C2",
      "why": "…",
      "why_source": "transcript:<session A>",   // transcript:<id> | commit | interview | inferred
      "files": ["app/settings/page.tsx"],
      "marks": [
        {
          "n": 1,                        // global callout number → legend ①
          "route": "/settings",
          "target": "the new section in the settings dialog",
          "selector_hint": "[data-testid=settings-section]",   // best-effort; may be null
          "container_hint": "[data-testid=settings-dialog]",
          "framing": "element+context",  // full-page | element | element+context | before-after | none
          "callout": "the new section",
          "screenshot": "screenshots/C1-settings.png"
        }
      ],
      "acceptance_seed": ["The new section is visible in the settings sidebar"]
      // acceptance_seed items are BEHAVIOURAL — what a person observes in the running product.
      // No compile checks, no class name assertions. These become the "Looks right when" list.
    }
  ]
}
```

## `PRD.md` (human-facing; **narrative order** = `prd_order`)

`PRD.md` is **human-only** — what a person sees or experiences, why the decision was made, and what
"done" looks like from a product perspective. It does **not** embed implementation details or the
prompt; those belong in `IMPLEMENTATION.md`. Follow the canonical structure above (one H1, metadata,
Summary, H2 per feature, four H3 sub-sections).

**Language rule:** no component names, CSS classes, TypeScript types, i18n keys, API function names,
or file paths in `PRD.md`. If you find yourself writing a class name or function call, stop — move
it to `IMPLEMENTATION.md`.

**Screenshot rule:** every section gets at least one screenshot. A section can have multiple marks
(①②③ globally numbered) — use as many as needed to show all distinct visible effects. Only omit
screenshots for product-invisible changes (build config, server-only migration, CI scripts).

**"Looks right when" rule:** items are observable by a person in the running product — no compile
checks, no CSS class assertions. Could a PM read this without opening the codebase? If not, strip it.

````markdown
# PRD — <feature>
**Branch:** `<branch>` · **Base:** `<base>` @ `<sha>` · **Designer:** <name> · **Date:** <date>
**Status:** Ready for dev

## Summary
- <what this change is, at a glance — plain product terms>
- <the user-facing outcome / why it matters>
- Prototyped — reproduce **production-quality** per each section's implementation prompt
  (in `IMPLEMENTATION.md`, merged under the section in the Lark doc).

> **Reading order.** Sections follow the designer's view: screens first, then the dialogs found
> inside them, then shell/wordmark. Build order differs — each heading's `[build: …]` hint and the
> per-section prompt give the developer the sequence.

---
## C1 — <containing screen>            [build: needs C2 first]

<!-- Narrative-first: the screen a user lands on. It is built AFTER the dialog it opens (C2). -->
![C1](screenshots/C1-settings.png)
**Legend:** ① <what the callout marks, in plain words>

### What changed
<what a person sees or experiences — no code names, no CSS, no types>

### Why
<product rationale, one or two sentences> *(source: <why_source>)*

### Looks right when
- [ ] <something verifiable by looking at or clicking the running product>
- [ ] <another observable outcome>

### Implementation prompt
_→ `IMPLEMENTATION.md` §C1 (merged into the Lark doc here as a code block, preceded by the ⚠ disclaimer)._

---
## C2 — <the dialog C1 opens>            [build: first · no deps]

<!-- A section may carry multiple marks (each its own image + legend) for distinct visible areas. -->
![C2-a](screenshots/C2-dialog.png) ![C2-b](screenshots/C2-trigger.png)
**Legend:** ② <callout for first mark>   ③ <callout for second mark>

### What changed
<plain product description covering both marks>

### Why
<rationale> *(source: <why_source>)*

### Looks right when
- [ ] <observable outcome relating to first mark>
- [ ] <observable outcome relating to second mark>

### Implementation prompt
_→ `IMPLEMENTATION.md` §C2 (merged into the Lark doc here as a code block, preceded by the ⚠ disclaimer)._
````

> The `C`-ids are stable join keys (manifest, `depends_on`, screenshot filenames, Lark `block_map`);
> they stay fixed across reorders. `prd_order` controls the PRD/Lark sequence; `impl_order` controls
> `IMPLEMENTATION.md`.

## `IMPLEMENTATION.md` (per-section, **build order** = `impl_order`; **environment-agnostic**)

Ordered by `impl_order` (dependencies first), so a developer reads top-to-bottom. Same sections as
the PRD (same `C`-ids), resequenced. Each section's prompt is **one code block** — Goal, code refs,
diff, acceptance, and verify all inside a single fence, with the diff as plain text **inside** it
(not its own nested fence). The Lark publish step drops this whole block in as a single copyable code
block under the matching (narrative-ordered) PRD section.

````markdown
## C2 — <the dialog>            [build: first · no deps]

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

Verify: open <screen> and match it against screenshots/C2-*.png (callout ②).
```
````

Rules:
- No "Why it matters" here — rationale lives only in `PRD.md`.
- The diff + acceptance + screenshot reference must be enough to implement with **no** access to the
  prototype repo; the git refs are a convenience for those who have access.
- **One code block per section, no nested fences.** Everything from Goal to Verify lives in that
  single block (the diff is plain text inside it). The Lark publish step embeds the **entire** block
  as one code block under the matching PRD section — never just the diff.

# prototype-to-prd — Skill Design

**Date:** 2026-06-03
**Status:** Approved (design); ready for writing-skills TDD build
**Skill name:** `prototype-to-prd`
**Type:** Personal Claude Code skill (`~/.claude/skills/prototype-to-prd/`)

> **Refined by** [`2026-06-03-multi-tool-install-and-prd-lark-merge-design.md`](2026-06-03-multi-tool-install-and-prd-lark-merge-design.md):
> the `PRD.md`/`IMPLEMENTATION.md` split is retained **locally** (separate files), but the two are
> **merged per section in the published Lark Docx** (the prompt as a copyable code block under each
> section). The local `PRD.md` is human-only.

---

## Purpose

Produce a developer-ready **handoff PRD** from a PM/UX designer's prototype work. The
designer makes quick-and-dirty changes (on a branch, or in a standalone prototype project);
the skill gathers the code changes + design intent, drives a browser to capture **annotated
before/after screenshots**, and assembles a **step-by-step PRD** that contains both
human-facing content (what / why / acceptance) and **per-section implementation prompts** for a
developer or another AI agent to reproduce the work production-quality.

Output is a local Markdown bundle (source artifact) **and** a published standalone Lark Docx
(shareable snapshot). The skill supports **updating** a previously generated PRD in place
rather than regenerating from scratch.

---

## Locked decisions

| # | Decision | Choice |
|---|----------|--------|
| 1 | Intent source | **Hybrid** — read agent session transcript(s) if present (enrichment), else fall back to diff + commit messages + a short designer interview. |
| 2 | Change → screen mapping | **Infer, then confirm** — auto-map changed page files to routes + trace shared-component usage; designer confirms/corrects at Checkpoint A. |
| 3 | Annotation | **Agent-drawn callouts** (red dashed outline + red circled numbers, numbered globally), with human `show --annotate` as the fallback for elements the agent can't locate. |
| 4 | Change scope | **Pluggable scope resolver** (see Addition A). Default for branch-off-product = fork-point (three-dot) vs HEAD, baseline `origin/main`, overridable. |
| 5 | Output | **Local Markdown bundle (source of truth) + published standalone Lark Docx (snapshot).** |
| 6 | Step unit | **Implementation-aware logical change** (see Clustering). Explicit-invoke trigger only. |

---

## Architecture

Dataflow: once the change set is gathered and analyzed, the PRD prose and the screenshots are
independent and only re-converge at assembly. So the pipeline is one sequential analysis phase,
then two parallel tracks, then a join.

```
PHASE 0 — resolve config & scope ──► PHASE 1 — gather+analyze → manifest ──►
PHASE 2 — { Track P: prose | Track S: screenshots } ──► join ──► PHASE 3 — assemble + publish
```

The two parallel tracks are made safe by a **change-set manifest** produced in Phase 1: it
pre-assigns each change's ID, callout number, screenshot filename, framing, and selector hints,
so the tracks never need to communicate. They join purely by change ID.

- **Track P** (the **main agent** — high-judgment work) writes PRD prose + implementation prompts.
- **Track S** (a **dispatched subagent** — browser-bound, mechanical) captures + annotates
  screenshots and returns `{screenshots[], misses[]}`.
- A subagent can't pause for human input, so **Checkpoint B (human annotation of misses) runs at
  the join, handled by the main agent.**

Cross-referenced skills (not duplicated): `superpowers:dispatching-parallel-agents` (Track S),
`superpowers:using-git-worktrees` (before/after base render), `lark-doc` (publishing),
`playwright-cli` (browser).

---

## Anti-hardcoding principle (critical)

Environment specifics are **inputs the skill resolves at runtime**, never constants in its text:

- `PREVIEW_BASE` (preview host+port), repo location, branch under review, base ref, Lark target
  folder — all resolved from the project's own conventions (e.g. this project's `CLAUDE.md`
  specifies host + port 3100) or by asking the operator.
- **`IMPLEMENTATION.md` carries ZERO assumptions about the prototyping environment** (no SSH, no
  IP, no port, no `frontend/`-only or `*-prototype` rules). The implementing developer is on an
  unknown machine/port. The only portable references are git refs + the embedded diff; the inline
  diff + acceptance + screenshot are sufficient to implement with no repo access.

This also makes the skill reusable beyond deer-flow.

---

## Phase 0 — Resolve config, scope, and preconditions

1. **Detect mode** (Addition A):
   - `branch-diff` — HEAD descends from a real base branch (e.g. `origin/main`).
   - `standalone` — no product baseline.
2. **Resolve scope** via the scope resolver:
   - `branch-diff` default: **fork-point** = `git merge-base <base> HEAD`; diff `<fork-point>..HEAD`.
     Baseline default `origin/main`, overridable.
   - `standalone` strategies (operator picks): whole project · since a chosen commit/tag/snapshot ·
     a commit range · an explicit file/feature selection.
3. **Select intent sources** (Addition B): list recent project sessions
   (`~/.claude/projects/<slug>/*.jsonl`); operator ticks which transcript(s) belong to this PRD
   (may be multiple parallel sessions). Transcripts are enrichment only.
4. **Resolve runtime config:** `PREVIEW_BASE`, repo+branch, Lark target folder.
5. **Check for an existing manifest** for this feature → if found, enter **update mode**
   (see Phase 3 / Addition C); else **create mode**.
6. **Preconditions (fail fast):** preview reachable at `PREVIEW_BASE` and showing the prototype
   state; `playwright-cli` browser open (optionally load saved auth/storage-state for
   authenticated screens); `lark-doc` available; scope diff non-empty.

---

## Phase 1 — Gather & analyze → `manifest.json`

1. Compute the change set per the resolved scope.
2. Collect commit messages on the branch/range; load the selected transcript(s).
3. **Cluster into implementation-aware sections** (judgment — see below).
4. Infer routes (Next.js app-router file→route + shared-component usage trace).
5. For each section assign: `order`, `depends_on`, callout number(s) `n`, `framing`,
   `screenshot` filename(s), `selector_hint` / `container_hint`, `callout` text, `why` +
   `why_source` (attributed to a session/commit/interview/inferred), `acceptance_seed`.
6. Write `manifest.json` (draft).
7. **⏸ Checkpoint A** — present sections + **order + dependencies** + routes + framing; the
   designer confirms/reorders and answers interview questions to fill any `why` gaps. (The order
   is the developer's implementation roadmap, so it is confirmed here.)

### Clustering (implementation-aware) — refines decision #6

A "section" is a unit that is **both** a coherent design change **and** an independently
implementable, verifiable chunk, ordered for sequential implementation. Clustering weighs:

- **Design cohesion** — one user-visible change.
- **Implementation cohesion** — changes touching the same component/file that must move
  together stay in one section; "build a shared component" vs "wire it into the screen" may be
  split into two ordered sections when that's the cleaner build sequence.
- **Dependency ordering** — foundational pieces (shared component, util, type) ordered before
  the screens that consume them; recorded in `depends_on`.
- **Independently shippable** — each section has its own acceptance criteria + screenshot.

---

## Manifest schema

```jsonc
{
  "feature": "settings-theme-toggle",
  "mode": "branch-diff",                 // branch-diff | standalone
  "scope": {
    "strategy": "fork-point",            // fork-point | commit-range | since-ref | files | whole-project
    "base": "origin/main",               // resolved fork-point sha also recorded; null when N/A
    "range": null,
    "paths": []
  },
  "sessions": ["<transcript path/id>", "..."],   // may span multiple parallel sessions
  "branch": "settings-theme-prototype",
  "date": "2026-06-03",
  "designer": "gaoshihan",
  "bundle_path": "prd/2026-06-03-settings-theme-toggle/",
  "lark": {
    "doc_token": "doxcn…",
    "url": "https://…",
    "block_map": { "C1": ["blk1", "blk2"], "C2": ["blk7"] }   // section → Lark block IDs (for in-place update)
  },
  "changes": [
    {
      "id": "C1",
      "order": 1,
      "depends_on": [],
      "title": "Build the 3-state ThemeToggle component",
      "intent": "auto / light / dark as a segmented toggle, not a <select>",
      "why": "dropdown hid the options; toggle shows all three at a glance",
      "why_source": "transcript:<session A>",   // transcript:<id> | commit | interview | inferred
      "files": ["components/ThemeSelect.tsx", "app/settings/page.tsx"],
      "marks": [
        {
          "n": 1,                                // global callout number → legend ①
          "route": "/settings",
          "target": "the theme <select> in the Appearance card",
          "selector_hint": "[data-testid=theme-select]",   // best-effort, may be null
          "container_hint": "[data-testid=appearance-card]",
          "framing": "element+context",          // full-page | element | element+context | before-after | none
          "callout": "auto / light / dark toggle",
          "screenshot": "screenshots/C1-settings.png"
        }
      ],
      "acceptance_seed": ["All three options visible without opening a menu"]
    }
  ]
}
```

The manifest is **persistent run-state**: `bundle_path`, `lark.*`, `scope`, and `sessions`
enable update mode within and across sessions.

---

## Phase 2 — Two parallel tracks

### Track P (main agent) — prose + implementation prompts

For each section, in `order`, produce the section's human content and its inline implementation
prompt (see Artifacts). References screenshots by their pre-assigned filename + callout number
(the image need not exist yet).

### Track S (dispatched subagent) — screenshots + callouts

**Per mark** in the manifest:

```
1  goto     playwright-cli goto "$PREVIEW_BASE<route>"
2  locate   try selector_hint (playwright-cli eval); else read a11y snapshot, match `target` → ref
            (and container ref when framing=element+context)
3  outline  playwright-cli highlight <ref> --style="outline:3px dashed #e5484d"
4  label    playwright-cli run-code (scripts/badge.js): inject a red circled number `n` badge,
            absolutely positioned at the element's getBoundingClientRect
5  shoot    full-page        → playwright-cli screenshot --filename=<file>
            element          → playwright-cli screenshot <target-ref> --filename=<file>
            element+context  → playwright-cli screenshot <container-ref> --filename=<file>
            before-after     → see below
            none             → skip (non-visual change)
6  reset    playwright-cli highlight --hide + remove injected badge nodes (runs even on error)
```

- Multiple marks on the same screen → draw all badges, one screenshot. Marks across routes →
  separate screenshots.
- **Locate failure** → plain full-page screenshot placeholder + record a **miss**
  `{id, route, target}`. Never guesses, never blanks.
- Track S **returns** `{screenshots[], misses[]}` and never talks to the operator.

#### `before-after` framing (heaviest mode — only when a mark is explicitly flagged)

"After" is free (preview shows the prototype). "Before" requires rendering the base state, but
**we must never switch branches on the shared remote checkout** (multi-session safety). So:

```
Once per run, if any mark is before-after:
  git worktree add <tmp> <fork-point-sha>      # read-only, no branch switch, complies with R3/R5
  pnpm install + next dev on an EPHEMERAL FREE port (not 3000, not the main preview port) = BASE_PREVIEW
Per before-after mark:
  before = screenshot BASE_PREVIEW<route> (same target/framing)
  after  = screenshot $PREVIEW_BASE<route> (with the ① callout)
  compose side-by-side "BEFORE | AFTER" (scripts/compose_before_after.sh) → <file>
Teardown (always, even on failure): stop BASE_PREVIEW; git worktree remove <tmp>
```

Cost is amortized (base built once, reused). **Fallback** if the base render fails: ask operator
for a before image, or downgrade the mark to after-only `element+context` + flag in the PRD.

### ⏸ Checkpoint B (join, main agent)

For each Track-S miss: open `playwright-cli show --annotate` on that route; operator draws the
box + types a note; the skill saves the annotated image as the change's screenshot and folds the
note into that section. If the operator is offline, the placeholder stays with a
`⚠ needs manual mark` flag — nothing ships silently unmarked.

---

## Phase 3 — Assemble & publish

**Bundle-first ordering** — assemble the local bundle *before* publishing so an external (Lark)
failure never loses work.

1. Write the bundle:
   ```
   prd/<date>-<feature>/
     manifest.json
     PRD.md
     IMPLEMENTATION.md
     screenshots/  (C1-*.png, …, callouts burned in)
   ```
2. **Publish / update the standalone Lark Docx** (delegated to `lark-doc`):
   - **Create mode:** create Docx in the resolved target folder; append blocks **in `order`**;
     per section: heading → uploaded screenshot image block → human content → inline
     implementation prompt. Record `lark.doc_token`, `url`, and `block_map`.
   - **Update mode (Addition C):** apply **targeted block ops** to the *same* doc via `block_map`
     (replace text, swap image media, insert/delete/move section blocks for added/removed/
     reordered sections); refresh `block_map`; keep the same URL.
   - **Reliability fallback:** if per-block image surgery proves flaky, rebuild the doc **body
     wholesale under the same `doc_token`** so the **URL stays stable** even without block-level
     precision.
3. **Return:** Lark doc URL + local bundle path.
4. **Teardown:** remove worktree + base preview if created.

---

## Artifacts (templates)

### `PRD.md` (human-facing; sections ordered by implementation sequence)

```markdown
# PRD — <feature>
**Branch:** <branch> · **Base:** <base @ sha> · **Designer:** <name> · **Date:** <date>
**Status:** Ready for dev

## Summary
<2–3 sentences over the whole change; note it was prototyped and should be reproduced
production-quality per the implementation prompts.>

---
## C1 — <title>            [implement first · no deps]
![C1](screenshots/C1-settings.png)
**Legend:** ① <callout>

**What changed.** <plain language>
**Why.** <rationale> *(source: <why_source>)*
**Acceptance criteria**
- [ ] …

── Implementation prompt ──
<the C1 block from IMPLEMENTATION.md, inline>

## C2 — <title>            [depends on C1]
…
```

### `IMPLEMENTATION.md` (per-section, ordered; portable — no environment specifics)

```markdown
## C1 — <title>            [implement first · no deps]

**Goal:** <what to build, behavior-level>

**Exact prototype code (reuse as-is if convenient):**
- Prototype branch `<branch>` @ `<sha>`  (repo: <origin url>)
- Files: `<files>`
- If you have repo access: `git show <sha>:<file>`

**Reference diff (reproduce in your project's conventions, or lift the code above):**
\`\`\`diff
<fork-point diff scoped to this section's files>   # standalone mode: the prototype files themselves
\`\`\`

**Acceptance criteria (Definition of Done):**
- [ ] …

**Verify:** in your dev environment, open the <screen> and match it against
screenshots/C1-*.png (callout ①).
```

(No "Why it matters" in `IMPLEMENTATION.md` — rationale lives only in `PRD.md`.)

---

## Skill file layout

```
prototype-to-prd/
  SKILL.md          # phase flow + the two checkpoints (the spine)
  templates.md      # manifest.json + PRD.md + IMPLEMENTATION.md skeletons; section structure
  reference.md      # callout style spec, framing→screenshot mapping, worktree base-render recipe,
                    #   lark create/update block-by-block steps, scope-resolver detail
  scripts/
    badge.js                 # injected DOM callout payload (playwright-cli run-code)
    compose_before_after.sh  # side-by-side BEFORE|AFTER image composition
```

Clustering and route-inference stay **inline judgment in SKILL.md** (not scriptable). Only the
genuinely reusable/mechanical bits (callout injection, image compose) get their own files.

### Trigger / `description` (CSO — triggering conditions only, no workflow summary)

> Use when a PM or designer has finished prototype changes on a branch (or in a standalone
> prototype project) and needs a developer-ready handoff PRD — annotated before/after
> screenshots plus per-step implementation prompts generated from the diff and design intent.

Explicit-invoke only (heavyweight, side effects: drives a browser, may spin up a second preview,
publishes a Lark doc).

---

## Error handling

| Situation | Handling |
|---|---|
| Preview unreachable at `PREVIEW_BASE` | Phase 0 precondition fails fast; tell operator how to start it (from project config); stop. |
| Empty change set | Abort with "no changes vs `<base>`" before expensive work. |
| Change has no visible UI | `framing: none` — no screenshot; PRD notes "non-visual change." |
| Element can't be located (miss) | Placeholder + miss → Checkpoint B human `show --annotate`, or downgrade + flag. No silent blank. |
| `before-after` base render fails | Ask operator for a before image, or downgrade to after-only + flag. |
| Stateful / auth'd screen | Phase 0 loads saved auth/storage-state, or operator logs in / pre-navigates before Track S. |
| Transcript missing/ambiguous | Enrichment only; fall back to commits + interview. |
| Lark publish/update fails | Local bundle already written; report failure + return bundle path; operator retries. |
| Per-mark browser error | Reset runs before next mark; teardown still guaranteed. |

**Principles:** bundle-first ordering · no silent blanks/caps (every miss/downgrade/skip is
flagged in the PRD and surfaced to the operator) · guaranteed teardown · fail fast on
preconditions · read-only on the remote `frontend/` (never edits it, never switches the shared
branch; base preview binds a free ephemeral port).

---

## Residual risks (v1 deliberately does not solve)

1. **Local bundle is plain files, not git-versioned** — `codecraft-prototype` is not a git repo;
   canonical history = the remote prototype branch + Lark snapshots. (The skill does not claim
   "version-controlled.")
2. **Clustering & section-ordering are judgment** — Checkpoint A is the human safeguard.
3. **diff→on-screen-element mapping is heuristic** — modals/deeply-conditional UI may need
   operator pre-navigation; misses fall to Checkpoint B.
4. **Stateful/auth'd screens** may need setup to render the change.
5. **Large change sets run slowly** (sequential within each track) — parallel-per-change is a
   deliberately deferred future optimization.
6. **`before-after` is costly** (worktree + base build) — used only when a mark is flagged.
7. **In-place Lark block updates are the trickiest part** — mitigated by the
   same-token-wholesale-rebuild fallback that keeps the URL stable.

---

## Build plan (next step)

Build via the **writing-skills RED→GREEN→REFACTOR** cycle:

- **RED** — baseline: ask an agent (no skill) to produce a handoff PRD from a sample prototype
  branch; capture the failures/omissions verbatim (likely: no annotated screenshots, leaks
  environment specifics into the dev prompt, no implementation-aware ordering, regenerates
  instead of updating).
- **GREEN** — write `SKILL.md` + supporting files addressing those specific failures.
- **REFACTOR** — re-test with subagents; close loopholes; build the rationalization/red-flags
  table; verify on create *and* update flows.
```

---
name: prototype-to-prd
description: Use when a PM or designer has finished prototype changes (on a branch, or in a standalone prototype project) and needs a developer-ready handoff PRD — annotated screenshots plus per-step implementation prompts generated from the diff and design intent. Triggers include "turn this prototype into a PRD", "produce a handoff doc for the developer", "write up these design changes for engineering".
---

# Producing a handoff PRD from prototype work

## Overview

Turn a designer's quick-and-dirty prototype into a **developer-ready handoff PRD**: gather the
code changes + design intent, drive a browser to capture **annotated screenshots** of the
affected screens, and assemble a **step-by-step handoff** — human-facing content (what / why /
acceptance) plus **portable, per-section implementation prompts** for a developer or another AI
agent to reproduce the work production-quality.

Output is a **local Markdown bundle** (the source artifact) **and** a published **standalone Lark
Docx** (the shareable snapshot). Locally the bundle keeps `PRD.md` (human) and `IMPLEMENTATION.md`
(per-section prompts) as **separate files**; the **Lark Docx merges them per section**, embedding
each prompt as a copyable code block. Re-running **updates** the existing PRD in place — it never
silently regenerates a fresh one.

**Core dataflow:** one sequential analysis phase produces a *manifest*; then PRD prose and
screenshots run as **two parallel tracks** that only re-converge at assembly. The manifest is the
contract that lets them run without talking, and the persistent state that makes updates possible.

## When to use

- A designer/PM finished prototype changes and you're asked to hand them to engineering.
- Triggers: "turn this prototype into a PRD", "write up these changes for the dev", "produce the
  handoff doc / spec for this branch".

**When NOT to use:** implementing the change yourself (that's the developer's job — this skill
*hands off*); writing a from-scratch product spec with no prototype (use `superpowers:brainstorming`
→ `writing-plans`); a pure code review (use `/code-review`).

Explicit-invoke only — it's heavyweight (drives a browser, may spin up a second preview, publishes
a Lark doc). Do not auto-fire.

## Non-negotiables

These are exactly the things an unguided agent skips. Do not skip them:

1. **Every section needs at least one screenshot unless the change is product-invisible.** A
   text-only PRD is a failure. `framing: none` means the change leaves **no visible state anywhere
   in the running product** (e.g. a build config change, a server-only migration, a CI script) — not
   merely that the underlying code is a type rename or an i18n key. Any change that touches labels,
   text, icons, styles, layout, or user-observable behaviour needs at least one screenshot, even if
   the code change looks "non-visual". A section can have **multiple marks** — use as many as needed
   to show all distinct visible effects of the change. Number callouts globally (①②③…) across all
   marks in all sections.
2. **Keep `PRD.md` and `IMPLEMENTATION.md` separate locally; merge them in the Lark doc.** On disk
   they stay two files: `PRD.md` is human-only (what/why/acceptance), `IMPLEMENTATION.md` holds the
   per-section copy-pasteable prompts. When you **publish to Lark**, merge them — under each section,
   right after the human content, place that section's **entire** implementation prompt (Goal →
   verify, **not just the diff**) as a **single code block**, immediately followed by an
   **auto-generated disclaimer** callout (the prompt is a starting point, not verified code — the dev
   must review it before use). Render each mark's legend as the **image caption**, never as a
   duplicate text line. Never blend prompt and prose into one paragraph, and never leave a Lark
   section merely *linking to* or paraphrasing the prompt — the copyable block must be present
   in-section.
3. **Order sections by implementation dependency** (`order` + `depends_on`) so the handoff reads as
   a build sequence — foundational pieces (shared component/util/type) before the screens that use
   them. Group by *both* design cohesion and implementation cohesion, not by file.
4. **Always write `manifest.json`.** It is persistent state; without it the PRD can't be updated in
   place and you'll be forced to regenerate.
5. **`IMPLEMENTATION.md` must be environment-agnostic.** The developer is on an unknown machine,
   port, and workflow. NEVER put the prototyping environment's SSH host, IP, port, `frontend/`-only
   rule, or `*-prototype` branch rules into it. Portable references only: git refs + the embedded
   diff (which alone is enough to implement with no repo access).
6. **Never hardcode environment specifics in the skill's own commands.** Resolve `PREVIEW_BASE`,
   repo/branch, base ref, and the Lark target folder at runtime (read the project's `CLAUDE.md`/
   `README`, or ask). The skill must work in projects other than this one.
7. **No silent blanks or caps.** Every miss / downgrade / skipped screenshot is flagged in the PRD
   *and* surfaced to the operator.
8. **PRD.md uses product language, not code language.** "What changed" describes what a person sees
   or experiences — no component names, CSS classes, TypeScript types, i18n keys, API function names,
   or file paths. Those belong in IMPLEMENTATION.md. The **"Looks right when"** section lists only
   things verifiable by looking at or clicking the running product — no compile checks, no class name
   assertions. Gut check: could a non-developer PM read the PRD section and understand it without
   opening the codebase? If not, strip the technical details out.

## Phase flow

```
PHASE 0  resolve config & scope; create-vs-update decision; preconditions
PHASE 1  gather + analyze → manifest.json        ⏸ CHECKPOINT A
PHASE 2  ║ Track P (main agent): prose + impl prompts
         ║ Track S (subagent):   screenshots + callouts → {screenshots[], misses[]}
         ╚ join                                   ⏸ CHECKPOINT B
PHASE 3  assemble local bundle → publish/update Lark Docx (merge PRD+IMPL per section) → return link
```

### Phase 0 — resolve config, scope, preconditions

Resolve, never hardcode (see Non-negotiable #6):
- **Mode:** `branch-diff` (HEAD descends from a base branch like `origin/main`) or `standalone`
  (no product baseline).
- **Scope** (the scope resolver): `branch-diff` default = fork-point `git merge-base <base> HEAD`,
  diff `<fork-point>..HEAD` (this aggregates *all* commits on the branch — including those from
  multiple parallel sessions on the shared branch). `standalone` strategies: `whole-project` ·
  `since-ref` · `commit-range` · `files`. Baseline default `origin/main`, overridable.
- **Intent sources:** list recent sessions (`~/.claude/projects/<slug>/*.jsonl`); operator selects
  which transcript(s) belong to this PRD (may be several). Transcripts are *enrichment only* — never
  required.
- **Runtime config:** `PREVIEW_BASE`, repo+branch, Lark target folder.
- **Create vs update:** look for an existing `manifest.json` for this feature. Found → **update
  mode** (see Phase 3). If a PRD exists only as a hand-made Lark doc (no manifest), **backfill** a
  manifest by reading the doc's block structure via `lark-doc`, then proceed in update mode.
- **Preconditions (fail fast, before expensive work):** preview reachable at `PREVIEW_BASE` and
  showing the prototype state; `playwright-cli` browser open (load saved auth/storage-state for
  authenticated screens, or have the operator log in first); `lark-doc` available; scope diff
  non-empty (else abort: "no changes vs `<base>`").

### Phase 1 — gather & analyze → manifest

1. Compute the change set per scope; collect commit messages; load selected transcript(s).
2. **Cluster into implementation-aware sections** (judgment — this is not scriptable). See
   Non-negotiable #3.
3. Infer affected routes (Next.js app-router file→route + trace shared-component usage to screens).
4. Per section assign: `order`, `depends_on`, one or more marks (each with `n`, `framing`,
   `screenshot` filename, `selector_hint`/`container_hint`, `callout` text), `why` + `why_source`,
   `acceptance_seed` (behavioural — what a person observes in the running product; no compile checks
   or code assertions). `framing: none` only for product-invisible changes. Schema + framing rules:
   `templates.md`, `reference.md`.
5. Write `manifest.json` (draft).
6. **⏸ Checkpoint A** — present sections + **order + dependencies** + routes + framing; the
   designer confirms/reorders and answers interview questions to fill `why` gaps. The order is the
   developer's roadmap, so confirm it here.

### Phase 2 — two parallel tracks (dispatch Track S; keep Track P in the main agent)

- **Track P (main agent):** for each section *in `order`*, write the `PRD.md` section (human-only:
  what / why / "Looks right when") **and** its `IMPLEMENTATION.md` block (the copy-pasteable
  prompt). PRD language is product-level — no code names, CSS, or types (see Non-negotiable #8). Keep them as
  the two separate files — the PRD↔IMPL merge happens at Lark-publish time (Phase 3). References
  screenshots by their pre-assigned filename + callout number — the image need not exist yet.
- **Track S (dispatched subagent):** captures + annotates screenshots and returns
  `{screenshots[], misses[]}`. Dispatch per `superpowers:dispatching-parallel-agents`. Exact
  per-mark loop, framing→screenshot mapping, the `before-after` worktree recipe (uses
  `superpowers:using-git-worktrees`), and the callout-injection contract are in `reference.md`.
  A subagent **cannot** ask the operator anything — it does best-effort auto-callouts and returns
  misses; it never guesses an element and never ships a blank.
- **⏸ Checkpoint B (join, main agent):** for each Track-S miss, open `playwright-cli show --annotate`
  on that route; the operator draws the box + types a note; save the annotated image as the
  section's screenshot and fold the note in. If the operator is offline, keep the placeholder with
  a `⚠ needs manual mark` flag.

### Phase 3 — assemble & publish

**Bundle-first ordering** — write the local bundle *before* any Lark write, so an external failure
never loses work.

1. Write `prd/<date>-<feature>/{manifest.json, PRD.md, IMPLEMENTATION.md, screenshots/}`.
2. Publish/update the standalone Lark Docx via `lark-doc` (block-by-block steps in `reference.md`):
   - **Create:** new Docx in the resolved folder; append blocks in `order` (heading → one image
     block per mark, legend as the **image caption** not a separate text line → human content → the
     **entire** implementation prompt as one copyable **code block** under the section, not just the
     diff → an **auto-generated disclaimer** callout reminding the dev to review the prompt — the
     PRD↔IMPL merge). Record `lark.doc_token`, `url`, and `block_map` (section → block IDs) into the
     manifest. Caption + disclaimer rules: `reference.md`.
   - **Update:** apply **targeted block ops** to the *same* doc via `block_map` (replace text, swap
     image media, insert/delete/move blocks for added/removed/reordered sections); refresh
     `block_map`; keep the same URL. **Fallback** if per-block image surgery is flaky: rebuild the
     doc body wholesale under the same `doc_token` so the **URL stays stable**.
3. Return the **Lark URL + local bundle path**.
4. Teardown: remove the worktree + base preview if `before-after` created them (always, even on
   error).

## Templates & reference

- `templates.md` — `manifest.json`, `PRD.md`, `IMPLEMENTATION.md` skeletons + the per-section
  structure. Use these verbatim; don't invent a different layout.
- `reference.md` — callout style spec, framing→screenshot mapping, Track-S per-mark loop, the
  `before-after` worktree recipe, and `lark-doc` create/update steps.
- `scripts/badge.js` — injected DOM callout payload (run via `playwright-cli run-code`).
- `scripts/compose_before_after.sh` — side-by-side BEFORE|AFTER image composition.

## Common mistakes

| Mistake | Fix |
|---|---|
| Shipping a text-only PRD (no images) | Every section needs at least one screenshot unless product-invisible (#1). |
| Marking a section `framing: none` because the code change is a type/i18n/config file | `framing: none` = no visible state anywhere in the product. If it touches a label, style, or layout, it needs a screenshot (#1). |
| A section has only one screenshot but the change affects multiple distinct areas | Use multiple marks per section — as many as needed to show all visible effects (#1). |
| PRD "What changed" contains component names, CSS classes, type names, or function names | PRD uses product language only; code details go in IMPLEMENTATION.md (#8). |
| "Looks right when" lists TypeScript compile checks or CSS class values | Acceptance items must be observable by a person in the running product; technical DoD goes in IMPLEMENTATION.md (#8). |
| Local `PRD.md` carries the full prompt, or one blended doc | Keep `PRD.md` human-only and `IMPLEMENTATION.md` separate locally (#2). |
| Lark section only *links to* / paraphrases the prompt | Embed the section's full prompt as a copyable **code block** under that section in the Lark doc (#2). |
| Legend appears twice in Lark (image caption + a text line) | Put the legend in the image caption only; drop the `Legend:` paragraph when publishing (reference.md). |
| Lark prompt reads like final, ready-to-paste code with no caveat | Add the auto-generated "review before use" disclaimer callout after each prompt (#2, reference.md). |
| Sections grouped by file, or unordered | Cluster by design+implementation cohesion; order by `depends_on` (#3). |
| Leaking SSH/IP/port/`*-prototype` rules into the dev prompt | `IMPLEMENTATION.md` is environment-agnostic (#5). |
| Hardcoding `192.168.x.x:3100` in the skill's commands | Resolve `PREVIEW_BASE` at runtime (#6). |
| Regenerating a brand-new PRD on a re-run | Detect the manifest → update in place (Phase 0/3). |
| Switching the shared remote branch to get a "before" shot | Use a `git worktree` at the fork-point (reference.md); never switch the shared branch. |
| Doing the developer's production reality-check yourself | This skill *hands off*. Capture intent + reference; don't re-architect. |

## Red flags — STOP

- About to write a PRD with no screenshots → STOP, run Track S.
- About to mark a section `framing: none` because the code change is a type/i18n/config file → STOP, ask: does this change produce any visible text, icon, style, or layout in the running product? If yes, it needs a screenshot.
- About to write a component name, CSS class, type name, or function call in `PRD.md` → STOP, that belongs in IMPLEMENTATION.md (#8).
- About to paste the preview URL / SSH host / port into `IMPLEMENTATION.md` → STOP, that's not portable.
- About to `git checkout <base>` on the shared remote checkout → STOP, use a worktree.
- About to create a second Lark doc when one already exists → STOP, update in place.
- About to publish a Lark section whose implementation prompt is missing or just a link/paraphrase → STOP, embed the full prompt as a code block under that section.
- About to publish a screenshot's legend as BOTH an image caption and a separate text line → STOP, caption only (the text line is the duplicate).
- About to publish an implementation prompt with no "review before use" disclaimer after it → STOP, add the auto-generated disclaimer callout.
- Skipping `manifest.json` "because it's a one-off" → STOP, it's the update contract.

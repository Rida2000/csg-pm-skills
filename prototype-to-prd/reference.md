# Reference

Heavy/reused detail for `prototype-to-prd`. The spine is in `SKILL.md`; this is the how-to for the
mechanical parts.

## Resolving config at runtime (never hardcode)

| Input | How to resolve |
|---|---|
| `PREVIEW_BASE` (e.g. `http://host:port`) | Read the project's `CLAUDE.md`/`README` (this project's CLAUDE.md states host + port 3100); else ask the operator. |
| repo + branch under review | `git -C <repo> rev-parse --abbrev-ref HEAD`; confirm with operator. |
| base ref | default `origin/main`; operator may override (or pick a standalone scope strategy). |
| Lark target folder | ask the operator, or use a configured "PRD Handoffs" folder. |

Compute the fork-point change set:
```bash
FP=$(git -C <repo> merge-base <base> HEAD)
git -C <repo> diff "$FP"..HEAD              # whole change set (all commits, all sessions)
git -C <repo> diff "$FP"..HEAD -- <files>   # scoped to one section's files
```
Standalone strategies: `whole-project` (diff against the empty tree / list all files), `since-ref`
(`git diff <ref>..HEAD`), `commit-range` (`git diff <A>..<B>`), `files` (operator-listed paths).

## Callout style (consistent across the whole PRD)

- Outline: `3px dashed #e5484d` (red).
- Number badge: red filled circle, white digit, ~20px, at the element's top-left, slight offset.
- Numbering is **global** across the PRD (①②③…), assigned in the manifest as `n`.
- Marks are real DOM (so they appear in the screenshot), positioned at **document** coordinates
  (element rect + scroll offset) so they stay correct in full-page captures.

### Drawing a callout (per mark)

1. Navigate: `playwright-cli goto "$PREVIEW_BASE<route>"`.
2. Locate the element → get a CSS selector:
   - if `selector_hint` is set, verify it: `playwright-cli --raw eval "!!document.querySelector('<hint>')"`.
   - else read the a11y snapshot, find the ref matching `target`, then
     `playwright-cli generate-locator <ref> --raw` to get a selector.
3. Set params + draw:
   ```bash
   playwright-cli eval "window.__CALLOUT__={sel:'<selector>',n:1,label:'auto / light / dark toggle',color:'#e5484d'}"
   playwright-cli run-code --filename=<skill>/scripts/badge.js
   playwright-cli --raw eval "window.__CALLOUT__.found"   # 'true' = drawn; 'false' = miss
   ```
4. Screenshot per framing (below).
5. Reset before the next mark (always, even on error):
   ```bash
   playwright-cli eval "document.querySelectorAll('.pp-callout').forEach(n=>n.remove())"
   ```

If step 3 reports `found=false`, do **not** guess: take a plain full-page screenshot as a
placeholder and record a miss `{id, route, target}` for Checkpoint B.

## Framing → screenshot mapping

| `framing` | Command |
|---|---|
| `full-page` | `playwright-cli screenshot --filename=<file>` |
| `element` | `playwright-cli screenshot <target-ref> --filename=<file>` |
| `element+context` | `playwright-cli screenshot <container-ref> --filename=<file>` (locate `container_hint`) |
| `before-after` | see recipe below |
| `none` | skip — non-visual change; note it in the PRD |

Heuristic defaults (operator overrides at Checkpoint A): layout/new-section → `full-page`;
self-contained control → `element`; relabeled field in a form → `element+context`;
non-visual (util/config/type) → `none`. Never auto-pick the expensive `before-after`.

## `before-after` recipe (heaviest — only when a mark is flagged)

"After" is the running prototype preview. "Before" needs the base state rendered **without
switching the shared checkout's branch** (multi-session safety). Use an isolated worktree
(`superpowers:using-git-worktrees`):

```bash
# once per run, if any mark is before-after:
WT=$(mktemp -d)
git -C <repo> worktree add "$WT" "$FP"        # fork-point sha; read-only, no branch switch
( cd "$WT" && pnpm install && PORT=<free-ephemeral-port> pnpm exec next dev --port <port> & )
BASE_PREVIEW="http://<host>:<free-ephemeral-port>"
```
Pick a **free** ephemeral port — not 3000 (other app) and not the main preview port. Per mark:
```
before = screenshot BASE_PREVIEW<route> (same target/framing, no callout)
after  = screenshot $PREVIEW_BASE<route> (with the ① callout)
<skill>/scripts/compose_before_after.sh <before> <after> <file>
```
Teardown (always, even on failure):
```bash
pkill -f "next dev --port <port>"; git -C <repo> worktree remove --force "$WT"; rm -rf "$WT"
```
Fallback if the base render fails (deps/build): ask the operator for a before image, or downgrade
the mark to after-only `element+context` and flag it in the PRD.

## Authenticated / stateful screens

If a route needs login or specific app state, the change won't render on a bare navigate. Before
Track S: load a saved storage-state (`playwright-cli` storage-state), or have the operator log in
/ navigate to the right state once in the open browser. Flag any screen that still won't render.

## Publishing with `lark-doc`

Invoke the `lark-doc` skill (use `docs +create` / `docs +update` with `--api-version v2`). Upload
screenshots as image blocks (they already have callouts burned in — no Lark-native annotation).

**Create:**
1. Create a standalone Docx in the resolved folder, titled `PRD — <feature> (<date>)`.
2. Append blocks **in `order`**, per section: heading → image block (uploaded screenshot) →
   human content (what/why/acceptance, from `PRD.md`) → **the section's full implementation prompt
   from `IMPLEMENTATION.md`, rendered as a code block** (so the developer copies it straight from the
   section). The prompt goes **under the same section heading** — this is the PRD↔IMPLEMENTATION
   merge, and it happens **only** in the Lark doc; the local `PRD.md`/`IMPLEMENTATION.md` stay
   separate.
3. Record `lark.doc_token`, `lark.url`, and `lark.block_map` (section id → list of block ids,
   **including the prompt code block**) into `manifest.json`.

**Update (manifest exists):**
1. For each changed section, use `block_map` to target its blocks: replace text, swap the image
   block's media, **refresh the implementation-prompt code block**, and insert/delete/move blocks for
   added/removed/reordered sections. (Each section's blocks include its prompt code block, so the
   merge is preserved on every update.)
2. Refresh `block_map`; keep the same `doc_token` and URL.
3. **Reliability fallback:** if per-block image surgery proves flaky, rebuild the whole doc body
   under the same `doc_token` (clear + re-append) so the **URL stays stable**.

**Backfill (PRD exists only as a hand-made Lark doc, no manifest):** read the doc's block
structure via `lark-doc`, reconstruct a `manifest.json` (sections + `block_map` + `doc_token`),
write the local bundle, then proceed in update mode.

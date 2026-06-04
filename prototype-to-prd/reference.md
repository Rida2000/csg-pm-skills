# Reference

Heavy/reused detail for `prototype-to-prd`. The spine is in `SKILL.md`; this is the how-to for the
mechanical parts.

## Resolving config at runtime (never hardcode)

| Input | How to resolve |
|---|---|
| `PREVIEW_BASE` (e.g. `http://host:port`) | Read the project's `CLAUDE.md`/`README` (this project's CLAUDE.md states host + port 3100); else ask the operator. |
| repo + branch under review | `git -C <repo> rev-parse --abbrev-ref HEAD`; confirm with operator. |
| base ref | default `origin/main`; operator may override (or pick a standalone scope strategy). |
| `doc_language` | default **English**; operator may request Chinese/other. Drives the glossary labels (templates.md). |
| publish path + **auth** | resolve which publisher is available **and authenticated** (lark-doc skill, or `lark-cli`) **in Phase 0, before any capture** (see Publishing) — a late auth failure wastes the whole capture pass. |
| Lark target folder | ask the operator, or use a configured "PRD Handoffs" folder (or My Space). |

Compute the fork-point change set:
```bash
FP=$(git -C <repo> merge-base <base> HEAD)
git -C <repo> diff "$FP"..HEAD              # whole change set (all commits, all sessions)
git -C <repo> diff "$FP"..HEAD -- <files>   # scoped to one section's files
```
Standalone strategies: `whole-project` (diff against the empty tree / list all files), `since-ref`
(`git diff <ref>..HEAD`), `commit-range` (`git diff <A>..<B>`), `files` (operator-listed paths).

The agent **reads** this diff in Phase 1 to understand and cluster the change into sections — but the
implementation prompt **points** to it (`git show <sha>:<file>` / `git diff <fp>..<sha> -- <files>`)
rather than embedding it. Don't paste full diffs into the prompt or the doc.

## Callout style (consistent across the whole PRD)

- Outline: `3px dashed #e5484d` (red).
- Number badge: red filled circle, white digit, ~20px, at the element's top-left, slight offset.
- Numbering is **global** across the PRD (①②③…), assigned in the manifest as `n` at capture time.
  Because callout numbers are **burned into the images** but the PRD is sequenced by `prd_order`
  (narrative), the badges are **not** necessarily sequential top-to-bottom after reordering — that's
  fine; each image's legend matches its own badges. Add a one-line note in the Summary saying so.
- Marks are real DOM (so they appear in the screenshot), positioned at **document** coordinates
  (element rect + scroll offset) so they stay correct in full-page captures.

### Drawing a callout (per mark)

1. Navigate: `playwright-cli goto "$PREVIEW_BASE<route>"`.
2. Locate the element → get a CSS selector:
   - if `selector_hint` is set, verify it: `playwright-cli --raw eval "!!document.querySelector('<hint>')"`.
   - else read the a11y snapshot, find the ref matching `target`, then
     `playwright-cli generate-locator <ref> --raw` to get a selector.
3. Draw the callout **inside the page** — this is critical. The DOM drawing must run via
   `page.evaluate`. `playwright-cli run-code --filename=<file>` executes the file in **Node**, where
   a top-level `document`-using script silently no-ops (the `found: undefined` bug). Two equivalent
   ways:
   - **Via the script** (`scripts/badge.js` exports `async page => …` and reads params from
     `$PP_CALLOUT`, drawing inside `page.evaluate`):
     ```bash
     PP_CALLOUT='{"sel":"<selector>","n":1,"label":"<label>","color":"#e5484d"}' \
       playwright-cli run-code --filename=<skill>/scripts/badge.js     # prints true (drawn) / false (miss)
     ```
   - **Inline** (proven fallback — the whole draw lives in `page.evaluate`):
     ```bash
     playwright-cli run-code "async page => page.evaluate(p => { const el=document.querySelector(p.sel); if(!el) return false; /* …draw outline+badge+chip from badge.js… */ return true; }, {sel:'<selector>',n:1,label:'<label>',color:'#e5484d'})"
     ```
   `true` = drawn, `false` = miss. The outline/badge/chip DOM lives in `scripts/badge.js` (single source).
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
# Kill the preview by PORT, never `pkill -f <pattern>` — a name pattern can match (and kill) your
# own ssh/shell command line (the exit-255 self-kill seen in practice).
kill $(lsof -t -iTCP:<port> -sTCP:LISTEN 2>/dev/null) 2>/dev/null || true
git -C <repo> worktree remove --force "$WT"; rm -rf "$WT"
```
Fallback if the base render fails (deps/build): ask the operator for a before image, or downgrade
the mark to after-only `element+context` and flag it in the PRD.

## Authenticated / stateful screens

If a route needs login or specific app state, the change won't render on a bare navigate. Before
Track S: load a saved storage-state (`playwright-cli` storage-state), or have the operator log in
/ navigate to the right state once in the open browser. Flag any screen that still won't render.

## Publishing the Lark / Feishu Docx

The published doc **is** the human handoff, so it follows the **canonical structure** (templates.md):
one **H1** title + a **metadata line** (Branch / Base / Designer / Date / Status — always present),
a **`## Summary`**, then each feature as an **H2** with four **H3** sub-sections (What changed / Why
/ Looks right when / Implementation prompt) — sequenced by **`prd_order`** (narrative), in the
resolved **`doc_language`** (default English) using **idiomatic** glossary labels (never literal,
never `看起来正确当`). Screenshots already have callouts burned in (no Lark-native annotation).

### Phase-0 precheck (BEFORE any capture — auth is the #1 time-sink)

Resolve a publisher **and confirm it's authenticated**, or surface the blocker now so the operator
fixes credentials before 30+ minutes of screenshots:
- Preferred: the `lark-doc` skill, if installed and resolvable (watch for a **broken symlink** — its
  `~/.agents/skills/` target may be missing).
- Fallback: `lark-cli` directly ("feishu" = Lark's Chinese name):
  ```bash
  command -v lark-cli && lark-cli auth status    # want: status ready / available: true
  ```
  Not ready → **STOP and give the operator the fix below**; do not start capturing.

### Authoring — one Markdown source, then insert images

Assemble the whole doc as **one** Lark-flavored Markdown file in the bundle (`<bundle>/feishu-doc.md`)
following the canonical structure, then create + insert:
1. Build `feishu-doc.md`: H1 title + metadata line; `## Summary` + notes (incl. the burned-in-callout
   note); per feature **in `prd_order`** `## C<n> — <title>` → `### What changed` → `### Why` →
   `### Looks right when` → `### Implementation prompt` (a one-line ⚠ disclaimer, **then** the
   section's **entire** prompt as one ` ```text ` code block). Leave an image anchor under each
   `## C<n>`.
2. Create the doc from it:
   ```bash
   lark-cli docs +create --markdown @feishu-doc.md --title "PRD — <feature>（<date>）"
   ```
   Use **v1** (default) — `--markdown @file` works there. **Do NOT pass `--api-version v2`**: v2 wants
   `--content` (a different format) and rejects `--markdown` (the failed first attempt in practice).
3. Insert each screenshot under its section heading, **legend as the caption** (one image per mark,
   never a duplicate `Legend:` paragraph):
   ```bash
   lark-cli docs +media-insert --doc <doc_token> --file screenshots/C1-*.png --caption "① <legend>"
   ```
4. Record `doc_token`, `url`, `doc_language`, and `source_markdown: "feishu-doc.md"` into
   `manifest.json` (`block_map: {}` for markdown-import publishes).

### `lark-cli` auth — the fix when it isn't ready

`lark-cli` stores credentials in the macOS keychain, which a sandboxed/automated shell can't read.
Once, in the operator's **own Terminal** (or with the sandbox disabled):
```bash
lark-cli config keychain-downgrade            # materialize the key to a file (sandbox-readable)
lark-cli auth login --domain docs,drive       # browser device-flow; "Always Allow" keychain prompts
lark-cli doctor                               # expect auth: pass
```
Gotchas seen in practice: `10003 invalid_client` = the stored app credential is wrong/expired
(`lark-cli config init` with a valid app_id/secret); a local `https_proxy` can mangle the CN token
exchange (`LARK_CLI_NO_PROXY=1`); device-codes are single-use (one fresh code per attempt).

### Update (manifest exists)

A markdown-import publish has no per-block `block_map`, so **update = recreate from the saved
`source_markdown`**: re-assemble `feishu-doc.md`, then `docs +update --markdown @feishu-doc.md --doc
<doc_token>` to replace the body **in place** (URL stays stable) — or, if in-place replace isn't
supported, create a fresh doc and update `manifest.json`. Re-insert the screenshots. (If a `lark-doc`
skill with true block-level ops is available, prefer in-place block edits and a real `block_map`.)

**Backfill (PRD exists only as a hand-made Lark doc, no manifest):** read the doc via the publisher,
reconstruct a `manifest.json` (sections + `doc_token` + `source_markdown`), write the local bundle,
then proceed in update mode.

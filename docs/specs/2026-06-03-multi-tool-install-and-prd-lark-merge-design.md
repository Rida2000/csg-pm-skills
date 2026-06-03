# Design — multi-tool skill compatibility + installer, and PRD/Lark prompt merge

**Date:** 2026-06-03 · **Status:** Approved (brainstorming) → ready for implementation plan
**Repo:** `csg-pm-skills` (`github.com/Rida2000/csg-pm-skills`)

This spec covers two independent-but-co-shipped changes:

- **Part A** — make the repo's skills installable across **Claude Code, Codex, Cursor, and
  OpenCode**, via a single `install.sh` (local clone *and* `curl | bash`).
- **Part B** — in the `prototype-to-prd` skill, keep `PRD.md` and `IMPLEMENTATION.md` as **separate
  local files**, and **merge** them when generating the **Lark Docx** so each section carries its
  implementation prompt as a copyable code block.

They share one session and one likely PR, but have no code dependency on each other.

---

## Background — how each tool discovers skills (verified 2026-06)

| Tool | Skill format | Project skills dir | Global (per-user) dir | Native `SKILL.md`? |
|---|---|---|---|---|
| **Claude Code** | `SKILL.md` | `<repo>/.claude/skills/<name>/` | `~/.claude/skills/<name>/` | yes |
| **Codex** (OpenAI CLI) | `SKILL.md` | `<repo>/.agents/skills/<name>/` (scans cwd→repo root) | `~/.agents/skills/<name>/` | yes |
| **OpenCode** | `SKILL.md` | `<repo>/.opencode/skills/<name>/` — *also reads* `.claude/skills` & `.agents/skills` | `~/.config/opencode/skills/<name>/` | yes |
| **Cursor** | `.mdc` rule (+ `.md` command) | `<repo>/.cursor/rules/<name>.mdc`, `<repo>/.cursor/commands/<name>.md` | none (User Rules are settings-only) | **no — needs conversion** |

Required `SKILL.md` frontmatter for all three native tools: `name`, `description` — which the
repo's skills already have. So for Claude/Codex/OpenCode, "compatibility" is **placement**, not
transformation. **Cursor is the only tool requiring a format conversion**, and it is effectively
**project-scoped**.

Implementation environment facts that constrain the design:
- Default macOS shell is **bash 3.2.57** → the installer must avoid bash-4 features (associative
  arrays, `mapfile`/`readarray`, `${x,,}`, `**` globstar).
- Curl one-liner base URL: `https://raw.githubusercontent.com/Rida2000/csg-pm-skills/main/install.sh`.

---

## Goals / Non-goals

**Goals**
- One command installs any/all skills into whichever of the four tools the user has.
- A `SKILL.md`-native skill needs **zero per-tool authoring** — the same directory is reused.
- Cursor gets a faithful adapter: an agent-requested rule **and** an explicit `/command`.
- Safe, reversible installs: `--dry-run`, `--uninstall`, never touch unrelated files.
- `prototype-to-prd` Lark output is self-contained per section (copyable prompt), while local
  artifacts keep the clean human/agent file split.

**Non-goals**
- Supporting tools beyond the four named (Gemini CLI, Copilot CLI, etc.) — out of scope (YAGNI).
- A package-manager distribution (npm/brew). Clone + `curl` cover the ask.
- Cursor global/User-Rules install (no per-skill file location exists).
- Auto-updating installed copies (copy mode is re-run to update; symlink mode is live).

---

## Part A — multi-tool installer

### A1. Skill discovery (no repo restructure)
A skill is **any immediate subdirectory containing a `SKILL.md`**. The installer scans, in the repo
root: `*/SKILL.md` and (future-proofing) `skills/*/SKILL.md`. Today that resolves to
`prototype-to-prd/`. No manifest, no moving files. The skill's `name` is read from `SKILL.md`
frontmatter (fallback: directory name).

### A2. `install.sh` — single self-contained file (bash 3.2-safe)

```
./install.sh [SKILL ...] [options]

  --tools <list>     comma list of claude,codex,cursor,opencode (default: auto-detect installed)
  --all-tools        target all four regardless of detection
  --global           per-user install (default)
  --project [DIR]    install into a repo (default DIR = cwd); enables Cursor
  --link             force symlink placement
  --copy             force copy placement
  --list             print discovered skills + detected tools + resolved targets, then exit
  --uninstall        remove what this installer created (honors the same selectors)
  --dry-run          print actions; change nothing
  -h | --help
```

- **No positional `SKILL` args ⇒ install all discovered skills** (required for the non-interactive
  curl path). Positional args select a subset by skill name.
- Unknown skill name / unknown tool / unwritable target → clear error, non-zero exit.

Internal functions (each independently testable): `discover_skills`, `detect_tools`,
`resolve_placement` (link vs copy), `target_dir` (tool×scope→path), `place_skill`,
`convert_cursor`, `bootstrap_remote`, `do_uninstall`, `do_list`, `main`.

### A3. Per-tool target map

**Global scope** (`--global`, default):

| Tool | Target |
|---|---|
| claude | `~/.claude/skills/<name>/` |
| codex | `~/.agents/skills/<name>/` |
| opencode | `~/.config/opencode/skills/<name>/` |
| cursor | *skipped* — print: "Cursor has no per-skill global location; use `--project`." |

**Project scope** (`--project [DIR]`):

| Tool | Target |
|---|---|
| claude | `<DIR>/.claude/skills/<name>/` |
| codex | `<DIR>/.agents/skills/<name>/` |
| opencode | `<DIR>/.opencode/skills/<name>/` |
| cursor | `<DIR>/.cursor/skills/<name>/` + `<DIR>/.cursor/rules/<name>.mdc` + `<DIR>/.cursor/commands/<name>.md` (see A6) |

Each native target is the skill **directory** (link or copy). Parent dirs are created as needed.
If a target already exists, replace it only when it is one of ours (an existing symlink into our
repo/cache, or a copied dir whose `SKILL.md` `name` matches); otherwise refuse and warn (never
clobber unrelated user data).

> Note: OpenCode also reads `.claude/skills` and `.agents/skills`, so in project scope it is often
> already covered by the claude/codex targets. We still write its canonical `.opencode/skills` when
> opencode is selected, for predictability; with symlinks the duplication is free.

### A4. Tool auto-detection
A tool counts as "present" if its config dir exists **or** its binary is on `PATH`:
- claude: `~/.claude` or `command -v claude`
- codex: `~/.codex` or `command -v codex`
- opencode: `~/.config/opencode` or `command -v opencode`
- cursor: only considered in `--project` mode; there, default to **on** (writing `.cursor/*` is
  harmless even without the app). `--tools`/`--all-tools` override detection entirely.

### A5. Auto link-vs-copy + curl self-bootstrap
- **Placement default:** **symlink** when the installer runs from inside the source clone (it can
  resolve a sibling skill dir next to itself); **copy** when it cannot (the curl path). `--link` /
  `--copy` override.
- **Curl self-bootstrap:** `curl -fsSL <raw>/install.sh | bash` pipes the script with no repo around
  it. When the script cannot locate skills next to itself, it:
  1. clones `--depth 1` into `${XDG_CACHE_HOME:-$HOME/.cache}/csg-pm-skills` (repo + ref overridable
     via `CSG_SKILLS_REPO` / `CSG_SKILLS_REF`; defaults to this repo @ `main`);
  2. re-execs the **cloned** `install.sh` in **copy** mode, passing through all args, with an env
     guard (`CSG_SKILLS_BOOTSTRAPPED=1`) to prevent re-exec loops.
- Arg pass-through for curl: `curl -fsSL <raw>/install.sh | bash -s -- prototype-to-prd --project .`

### A6. Cursor adapter (the only transformation)
For each selected skill in `--project` mode, generate three things:

1. **`<DIR>/.cursor/skills/<name>/`** — the full skill directory (link/copy), so referenced support
   files (`templates.md`, `reference.md`, `scripts/…`) physically exist for Cursor to read.
2. **`<DIR>/.cursor/rules/<name>.mdc`** — front-matter:
   ```
   ---
   description: <SKILL.md `description`, verbatim>
   alwaysApply: false
   ---
   ```
   (`alwaysApply: false` + no `globs` ⇒ an *agent-requested* rule Cursor loads on demand by matching
   the description — the closest analog to skill auto-invocation.) Body = the `SKILL.md` body,
   prefixed with a **Resources** block that `@`-mentions the bundled files, e.g.
   `Resources (read as needed): @.cursor/skills/<name>/templates.md @.cursor/skills/<name>/reference.md`.
3. **`<DIR>/.cursor/commands/<name>.md`** — an explicit slash command:
   > Follow the skill at `.cursor/skills/<name>/SKILL.md` for this task: `$ARGUMENTS`

   giving `/<name>` parity with the other tools' explicit invoke.

**Frontmatter parsing:** a small `awk` routine splits the first `---`…`---` block from the body and
extracts single-line `name:` / `description:` values. Our skills use single-line frontmatter values;
if a value is detected to span multiple lines, the script errors loudly rather than emit a malformed
`.mdc`.

### A7. Safety: `--list`, `--dry-run`, `--uninstall`
- `--list` prints discovered skills (name + first line of description), detected tools, and the
  resolved target paths for the chosen scope — no mutation.
- `--dry-run` gates every create/link/copy/remove with a printed action line.
- `--uninstall` reverses installs for the selected skills/tools/scope: remove a symlink only if it
  points back into our repo/cache; remove a copied dir only if its `SKILL.md` `name` matches a repo
  skill; for Cursor also remove the matching `.cursor/rules/<name>.mdc`, `.cursor/commands/<name>.md`,
  and `.cursor/skills/<name>/`. Empty `skills/` parents are pruned; never deletes unrelated entries.

### A8. Tests — `test/install.test.sh` (dependency-free, test-first)
Plain shell assertions, run against a temp `HOME` and a temp project dir; **written RED → GREEN**:
1. **copy global** — `--global --copy --all-tools` lands each skill dir in `~/.claude/skills`,
   `~/.agents/skills`, `~/.config/opencode/skills` (under the temp HOME); cursor skipped with notice.
2. **project cursor** — `--project <tmp> --copy --tools cursor` produces a `.cursor/rules/<name>.mdc`
   with `alwaysApply: false` and the exact `description`, a `.cursor/commands/<name>.md`, and
   `.cursor/skills/<name>/SKILL.md`.
3. **link mode** — `--link` creates symlinks resolving back to the repo skill dir.
4. **uninstall** — reverses (1)/(2); leaves a planted unrelated file untouched.
5. **dry-run** — prints actions, creates nothing.
6. **default-all** — no positional args installs every discovered skill.

### A9. README updates
Replace the manual `ln -s` block with: the curl one-liner, the clone + `./install.sh` path, the
flags table, the per-tool target table, and the Cursor-conversion note. Update the tagline to name
**Claude Code, Codex, Cursor, and OpenCode** explicitly.

---

## Part B — keep both local files; merge into the Lark Docx

**Decision:** the local bundle keeps `PRD.md` (human-only) and `IMPLEMENTATION.md` (per-section
prompts) as **separate files**. The **merge happens only when generating the Lark Docx**: each Lark
section places its implementation prompt **under that same section**, rendered as a **code block**
(copyable). Bundle stays `{manifest.json, PRD.md, IMPLEMENTATION.md, screenshots/}`.

### B1. `templates.md`
- **`IMPLEMENTATION.md` template:** each section's prompt is **one code block** (Goal → code refs →
  diff → acceptance → verify, with the diff as plain text **inside** the block — no nested fence),
  kept per-section and environment-agnostic. This makes the Lark merge drop the **entire** prompt in
  as a single copyable code block (not just the diff).
- **`PRD.md` template:** make sections **human-only**. Replace the current
  `── Implementation prompt ── <the C1 block from IMPLEMENTATION.md, inline …>` lines with a
  one-line **pointer**, e.g. `_Implementation prompt → `IMPLEMENTATION.md` §C1 (merged into the Lark
  doc under this section)._` No prompt body is duplicated in the local `PRD.md`.
- **`PRD.md` opening section:** keep the **`Summary`** heading name, promote it to a **level-1
  heading (`# Summary`)**, and render it as **bullet points** (not prose) — a few bullets covering
  the whole change, including the "prototyped → reproduce production-quality per the per-section
  prompts" note.
- **Section IDs unchanged (decision):** headings keep the **visible stable `C1`/`C2` IDs**. They are
  the join key across the manifest, `depends_on`, screenshot filenames, and the Lark `block_map`, and
  staying fixed across reorders/inserts is what makes in-place PRD/Lark updates safe. (Chosen over a
  plain numbered list, which would renumber on every reorder.)
- **Header note (lines 3–5):** reframe the "split" — *local = two files (human `PRD.md` / prompts
  `IMPLEMENTATION.md`); the published **Lark Docx merges them per section.***

### B2. `reference.md` — Lark publishing
- **Create:** per section, append blocks **in `order`**: heading → image block (screenshot) → human
  content (what/why/acceptance, from `PRD.md`) → **the section's _entire_ prompt from
  `IMPLEMENTATION.md` as a single code block** (Goal → verify, **not just the diff**; copyable in
  Lark), placed **under the same section heading**.
- **Update:** same merge rule when refreshing a section's blocks; the implementation-prompt code
  block is part of each section's `block_map` entry so targeted updates replace it in place.

### B3. `SKILL.md`
- **Non-negotiable #2** — rewrite: the local bundle keeps `PRD.md` (human) and `IMPLEMENTATION.md`
  (prompts) **separate**; the **published Lark Docx merges them per section** — human content
  followed by the implementation prompt **as a copyable code block under the same heading**. Don't
  blend prompt and prose into one paragraph, and don't leave the Lark section pointing at an external
  file — the copyable block must be present in-section.
- **Non-negotiable #5** stays (`IMPLEMENTATION.md` is environment-agnostic).
- Update wording in the **phase-flow caption**, **Phase 2 Track P** (writes `PRD.md` human section +
  its `IMPLEMENTATION.md` block; merge is deferred to Phase 3 Lark publish), **Phase 3** (state the
  merge explicitly), the **common-mistakes** table, and **red-flags** so none imply the local
  `PRD.md` carries the prompt or that the Lark section may merely link out.

### B4. `README.md`
Clarify Output: the local bundle has **separate** `PRD.md` (human) and `IMPLEMENTATION.md` (prompts);
the **Lark Docx merges them per section** with the prompt as a copyable code block.

### B5. Historical spec note
Add one line to `docs/specs/2026-06-03-prototype-to-prd-skill-design.md` noting the `PRD.md`/
`IMPLEMENTATION.md` handling is refined by this spec (local split retained; merge occurs at Lark
publish).

---

## Testing & verification plan
- **Part A:** `test/install.test.sh` green (A8). Manual smoke: `./install.sh --list`; a `--project`
  install into a scratch dir inspected for the four tools' artifacts; a `--dry-run` global run.
- **Part B:** changes are skill prose/templates (no executable path). Verify by re-reading: local
  `PRD.md` template has no prompt body (pointer only); `reference.md` Create/Update specify a
  per-section code block; `SKILL.md` #2 and the touched sections are internally consistent (no
  remaining text implying the local `PRD.md` contains the prompt). Build the skill edits per
  `superpowers:writing-skills` (close loopholes; ensure an unguided agent can't produce a Lark
  section that only links to the prompt).

## Out of scope / future
- Gemini CLI / Copilot CLI targets, npm/brew distribution, Cursor User-Rules global install,
  auto-update of copied installs.

## Open questions
None outstanding — all four installer choices and the Part B merge behavior are decided.

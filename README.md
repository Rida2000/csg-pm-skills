# csg-pm-skills

PM / UX-handoff skills for **[Claude Code](https://claude.com/claude-code)**, **Codex**, **Cursor**,
and **OpenCode**. Each skill is a self-contained `SKILL.md` directory under this repo. Claude Code,
Codex, and OpenCode read `SKILL.md` natively; for Cursor the installer generates an equivalent rule
and slash command. Install with `./install.sh` (or a one-line `curl`) — see [Install](#install).

## Skills

### `prototype-to-prd`

Turns a designer's quick-and-dirty **prototype** into a developer-ready **handoff PRD**: gathers
the code changes + design intent, drives a browser to capture **annotated screenshots** of the
affected screens, and assembles a **step-by-step PRD** with both human-facing content
(what / why / acceptance) and **portable, per-section implementation prompts** for a developer or
another AI agent.

- **Output:** a local Markdown bundle (source of truth) — separate `PRD.md` (human) and
  `IMPLEMENTATION.md` (per-section prompts) — **and** a published Lark Docx (shareable snapshot)
  that **merges them per section**, embedding each prompt as a copyable code block. Re-running
  **updates** the existing PRD in place rather than regenerating it.
- **Pipeline:** one analysis phase produces a `manifest.json`; then PRD prose and screenshots run
  as two parallel tracks that re-converge at assembly, with two human checkpoints.
- **Design spec:** [`docs/specs/2026-06-03-prototype-to-prd-skill-design.md`](docs/specs/2026-06-03-prototype-to-prd-skill-design.md)

Files:

```
prototype-to-prd/
  SKILL.md       # the phase flow + checkpoints (the spine)
  templates.md   # manifest.json / PRD.md / IMPLEMENTATION.md skeletons
  reference.md   # callout style, framing→screenshot mapping, before/after worktree recipe, Lark steps
  scripts/
    badge.js                 # injected DOM callout payload (via playwright-cli run-code)
    compose_before_after.sh  # side-by-side BEFORE|AFTER image composition
```

## Install

`install.sh` installs each skill into whichever of **Claude Code**, **Codex**, **Cursor**, and
**OpenCode** you have. The three `SKILL.md`-native tools just get the skill directory placed in the
right folder; for **Cursor** the installer generates a `.cursor/rules/<name>.mdc` rule plus a
`.cursor/commands/<name>.md` slash command (project scope only).

**One-liner** (clones to a cache, then copies in):

```bash
curl -fsSL https://raw.githubusercontent.com/Rida2000/csg-pm-skills/main/install.sh | bash
# a subset, into a project (this is what enables Cursor):
curl -fsSL https://raw.githubusercontent.com/Rida2000/csg-pm-skills/main/install.sh | bash -s -- prototype-to-prd --project .
```

**From a clone** (symlinks by default, so `git pull` keeps every install current):

```bash
git clone https://github.com/Rida2000/csg-pm-skills.git && cd csg-pm-skills
./install.sh                                # all skills → every detected tool, globally
./install.sh --list                         # show skills, detected tools, resolved targets
./install.sh prototype-to-prd --project .   # one skill into the current repo (enables Cursor)
```

**Options**

| Flag | Meaning |
|---|---|
| `--tools <list>` | comma list of `claude,codex,cursor,opencode` (default: auto-detect installed) |
| `--all-tools` | target all four regardless of detection |
| `--global` | per-user install (default) |
| `--project[=DIR]` | install into a repo (default: cwd); **enables Cursor** |
| `--link` / `--copy` | force symlink / copy (default: symlink from a clone, copy via `curl`) |
| `--uninstall` | remove what the installer created (same selectors) |
| `--dry-run` | print actions, change nothing |

**Where skills land**

| Tool | Global | Project (`--project`) |
|---|---|---|
| Claude Code | `~/.claude/skills/<name>/` | `<dir>/.claude/skills/<name>/` |
| Codex | `~/.agents/skills/<name>/` | `<dir>/.agents/skills/<name>/` |
| OpenCode | `~/.config/opencode/skills/<name>/` | `<dir>/.opencode/skills/<name>/` |
| Cursor | — (no per-skill global location) | `<dir>/.cursor/{rules,commands,skills}/<name>` |

### Per-platform install & upgrade

Pick a scope once: **global** (default — available in every project for that tool) or
**`--project[=DIR]`** (scoped to one repo; required for Cursor). All commands below assume you've
cloned the repo and are in it (`git clone https://github.com/Rida2000/csg-pm-skills.git && cd
csg-pm-skills`); each maps 1:1 onto the `curl … | bash -s -- …` form if you prefer not to clone.

#### Claude Code
- **Install (global):** `./install.sh --tools claude` → `~/.claude/skills/<name>/`
- **Install (one repo):** `./install.sh --tools claude --project .` → `<repo>/.claude/skills/<name>/`
- **Use:** auto-discovered. These skills are explicit-invoke — just ask Claude (e.g. *"turn this
  prototype into a PRD"*) and it loads the skill.
- **Upgrade:** symlinked from a clone → `git pull` and it's already live. Copied (or installed via
  `curl`) → re-run the same install command.

#### Codex
- **Install (global):** `./install.sh --tools codex` → `~/.agents/skills/<name>/`
- **Install (one repo):** `./install.sh --tools codex --project .` → `<repo>/.agents/skills/<name>/`
  (Codex scans `.agents/skills` from the working dir up to the repo root.)
- **Use:** run `/skills`, or type `$` to mention a skill by name.
- **Upgrade:** `git pull` for symlinks; re-run the install command for copies.

#### OpenCode
- **Install (global):** `./install.sh --tools opencode` → `~/.config/opencode/skills/<name>/`
- **Install (one repo):** `./install.sh --tools opencode --project .` →
  `<repo>/.opencode/skills/<name>/`. (OpenCode also reads `.claude/skills` and `.agents/skills`, so a
  Claude or Codex project install is picked up automatically too.)
- **Use:** auto-discovered; mention the skill by name.
- **Upgrade:** `git pull` for symlinks; re-run the install command for copies.

#### Cursor — project scope only
- **Install:** `./install.sh --tools cursor --project .` — generates, in the repo:
  - `.cursor/rules/<name>.mdc` — an *agent-requested* rule (Cursor loads it on demand by its
    description, the closest thing to skill auto-invocation)
  - `.cursor/commands/<name>.md` — invoke explicitly as `/<name>`
  - `.cursor/skills/<name>/` — the skill's support files (`templates.md`, `reference.md`, scripts)
- **Use:** ask Cursor's agent for the task (the rule loads itself), or type `/<name>`.
- **Upgrade:** **re-run** `./install.sh <name> --tools cursor --project .`. The `.mdc` and command are
  *generated* files, so they don't refresh on `git pull` alone (the bundled `.cursor/skills/<name>/`
  does, if it was symlinked). Cursor has no per-skill global location, so there's no global install.

#### Upgrade / remove — quick reference
- **From a clone:** `cd csg-pm-skills && git pull && ./install.sh <the flags you used>`. Symlinked
  Claude/Codex/OpenCode installs are already current; re-running also regenerates Cursor rules and
  refreshes any copy installs.
- **Via curl:** re-run the same `curl … | bash` line — it refreshes the cached clone and re-copies.
- **Remove:** add `--uninstall` with the same selectors, e.g. `./install.sh --uninstall --tools
  claude`, or `./install.sh prototype-to-prd --uninstall --tools cursor --project .`. Use `--dry-run`
  first to preview.

> These skills are **explicit-invoke** (they don't auto-fire). `prototype-to-prd` also needs a
> running dev preview and, for the Lark publish step, the `lark-doc` skill and `playwright-cli`.

## Conventions

- Skills are **environment-agnostic**: they resolve preview URLs, repo/branch, and target folders
  at runtime rather than hardcoding them, so they work across projects.
- Each skill was built test-first (RED → GREEN → REFACTOR) per the `superpowers:writing-skills`
  methodology — baseline the failure, write the minimal skill that fixes it, close loopholes.

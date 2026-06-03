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

Then invoke a skill from your tool — these skills are **explicit-invoke** only. `prototype-to-prd`
expects a running dev preview and, for the Lark publish step, the `lark-doc` skill and
`playwright-cli`.

## Conventions

- Skills are **environment-agnostic**: they resolve preview URLs, repo/branch, and target folders
  at runtime rather than hardcoding them, so they work across projects.
- Each skill was built test-first (RED → GREEN → REFACTOR) per the `superpowers:writing-skills`
  methodology — baseline the failure, write the minimal skill that fixes it, close loopholes.

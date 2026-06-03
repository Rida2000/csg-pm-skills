# csg-pm-skills

PM / UX-handoff skills for [Claude Code](https://claude.com/claude-code) (and compatible agents).
Each skill is a self-contained directory under this repo; install a skill by symlinking it into
your agent's skills directory.

## Skills

### `prototype-to-prd`

Turns a designer's quick-and-dirty **prototype** into a developer-ready **handoff PRD**: gathers
the code changes + design intent, drives a browser to capture **annotated screenshots** of the
affected screens, and assembles a **step-by-step PRD** with both human-facing content
(what / why / acceptance) and **portable, per-section implementation prompts** for a developer or
another AI agent.

- **Output:** a local Markdown bundle (source of truth) **and** a published Lark Docx (shareable
  snapshot). Re-running **updates** the existing PRD in place rather than regenerating it.
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

Symlink a skill into your Claude Code skills directory so it's auto-discovered:

```bash
ln -s "$PWD/prototype-to-prd" ~/.claude/skills/prototype-to-prd
```

Then invoke it from Claude Code (it's explicit-invoke only). It expects a running dev preview and,
for the Lark publish step, the `lark-doc` skill and `playwright-cli`.

## Conventions

- Skills are **environment-agnostic**: they resolve preview URLs, repo/branch, and target folders
  at runtime rather than hardcoding them, so they work across projects.
- Each skill was built test-first (RED → GREEN → REFACTOR) per the `superpowers:writing-skills`
  methodology — baseline the failure, write the minimal skill that fixes it, close loopholes.

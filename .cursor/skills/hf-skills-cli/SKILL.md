---
name: hf-skills-cli
description: Install and manage Hugging Face agent skills via the hf CLI (hf skills add). Use when setting up skills for Codex, Cursor, OpenCode, Claude Code, or ~/.agents/skills.
---

# Hugging Face `hf skills` CLI

Installs skills from Hugging Face so coding agents can load them from `~/.agents/skills` (global) or `.agents/skills` (project).

## Prerequisites

- [Hugging Face Hub CLI](https://huggingface.co/docs/huggingface_hub/guides/cli) (`pip install huggingface_hub` or your env’s equivalent) with `hf` available.

## Global install (all projects)

Available in all projects; agents that load skills from `~/.agents/skills` pick them up (Codex, Cursor, OpenCode, etc.):

```bash
hf skills add --global
```

For **Claude Code**, use:

```bash
hf skills add --claude --global
```

## Project-only install (current repo)

```bash
hf skills add
```

For **Claude Code** in the current project:

```bash
hf skills add --claude
```

## When to use which

| Goal | Command |
|------|---------|
| Skills everywhere you work | `hf skills add --global` |
| Skills only in this repository | `hf skills add` (run from project root) |
| Claude Code–oriented layout | Add `--claude` to either command above |

## Notes

- Paths follow HF’s convention: global `~/.agents/skills`, project `.agents/skills`.
- After adding or updating skills, restart the agent or reload skills if your tool requires it.

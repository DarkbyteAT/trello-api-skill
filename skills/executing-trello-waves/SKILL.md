---
name: executing-trello-waves
description: Use when picking up implementation work from a Trello board — identifies ready cards by checking dependencies against Done and merged-to-main, analyses file conflicts between ready cards, creates worktrees, dispatches parallel agents, reviews output, and ships PRs with Trello lifecycle management
---

# Executing Trello Waves

Execute the next available wave of Trello implementation cards in parallel using git worktrees and subagents.

**Core principle:** Trello cards drive scope. One card = one worktree = one agent = one PR. The orchestrator (you) owns git, PRs, and Trello. Agents only write code.

**Dependency:** Load `trello-api` skill first (`/trello-api`).

## Before You Start

1. **Pull latest main:**
   ```bash
   git checkout main && git pull
   ```

2. **Load the Trello skill** — run `/trello-api` so you can query the board.

3. **Read repo docs** — `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, and any docs directory. These define how agents must work in this repo.

4. **Gather central context** — read key implementation files (models, services, CRUD, errors, clients, configs, tests). Include critical code **verbatim** in agent prompts rather than pointing to file paths — agents waste significant time re-reading files the orchestrator already has.

## Identify the Next Wave

```dot
digraph identify_wave {
    "Read Trello board columns" [shape=box];
    "For each Todo card, read Dependencies" [shape=box];
    "All deps in Done AND merged to main?" [shape=diamond];
    "Card is ready" [shape=box];
    "Card is blocked" [shape=box];
    "Any ready cards?" [shape=diamond];
    "Analyse file conflicts between ready cards" [shape=box];
    "Cards share files?" [shape=diamond];
    "Group into parallel wave" [shape=box];
    "Execute sequentially or split wave" [shape=box];
    "Present conflict analysis to user" [shape=box];
    "Inform user what blocks them, terminate" [shape=doublecircle];

    "Read Trello board columns" -> "For each Todo card, read Dependencies";
    "For each Todo card, read Dependencies" -> "All deps in Done AND merged to main?";
    "All deps in Done AND merged to main?" -> "Card is ready" [label="yes"];
    "All deps in Done AND merged to main?" -> "Card is blocked" [label="no"];
    "Card is ready" -> "Any ready cards?";
    "Card is blocked" -> "Any ready cards?";
    "Any ready cards?" -> "Analyse file conflicts between ready cards" [label="yes"];
    "Any ready cards?" -> "Inform user what blocks them, terminate" [label="no"];
    "Analyse file conflicts between ready cards" -> "Cards share files?";
    "Cards share files?" -> "Execute sequentially or split wave" [label="yes"];
    "Cards share files?" -> "Group into parallel wave" [label="no"];
    "Execute sequentially or split wave" -> "Present conflict analysis to user";
    "Group into parallel wave" -> "Present conflict analysis to user";
}
```

**Dependency verification:** Cards can be "Done" on Trello with unmerged PRs. Verify with `git log` or `git branch -r` — treat unmerged dependencies as unmet.

**File conflict analysis:** For each ready card, list the files it will create or modify. Cards that share files cannot be parallelised — they will produce merge conflicts.

## Build Agent Prompts

Every agent prompt must include:

| Section | Content |
|---------|---------|
| **Worktree path** | Absolute path the agent must work in |
| **Shared context block** | Verbatim code for base classes, existing implementations the agent needs to call or follow, DI patterns |
| **File pointers** | `AGENTS.md`, `CONTRIBUTING.md`, architecture docs, relevant module READMEs — for reference if agent needs more detail |
| **Card context** | Full Trello card description (What, Why, Dependencies) and Definition of Done checklist items |
| **Quality gates** | Lint, type-check, and test commands appropriate for the project (e.g. `ruff format . && ruff check --fix`, `mypy .`, `pytest -m unit`) |
| **No git ops** | Agents must NOT commit, push, or create PRs — they write code and run quality gates only |

## Execute the Wave

```dot
digraph execute_wave {
    rankdir=TB;

    subgraph cluster_setup {
        label="Setup (sequential)";
        "Move cards Todo → Doing on Trello" [shape=box];
        "Create worktrees (one per card)" [shape=box];
        "Move cards Todo → Doing on Trello" -> "Create worktrees (one per card)";
    }

    subgraph cluster_dispatch {
        label="Dispatch (parallel)";
        "Launch one agent per card (run_in_background)" [shape=box];
    }

    subgraph cluster_review {
        label="Review and ship (sequential, per agent)";
        "Review agent output" [shape=box];
        "Fix issues in worktree" [shape=box];
        "Commit with descriptive message" [shape=box];
        "Push and create PR" [shape=box];
        "Tick DoD items on Trello card" [shape=box];
        "Move card Doing → Reviewing" [shape=box];

        "Review agent output" -> "Fix issues in worktree";
        "Fix issues in worktree" -> "Commit with descriptive message";
        "Commit with descriptive message" -> "Push and create PR";
        "Push and create PR" -> "Tick DoD items on Trello card";
        "Tick DoD items on Trello card" -> "Move card Doing → Reviewing";
    }

    subgraph cluster_post {
        label="Post-review";
        "Triage automated review comments on PRs" [shape=box];
        "Merge PRs" [shape=box];
        "Move cards Reviewing → Done" [shape=box];
        "Clean up worktrees and branches" [shape=box];
        "Pull main" [shape=box];

        "Triage automated review comments on PRs" -> "Merge PRs";
        "Merge PRs" -> "Move cards Reviewing → Done";
        "Move cards Reviewing → Done" -> "Clean up worktrees and branches";
        "Clean up worktrees and branches" -> "Pull main";
    }

    "Create worktrees (one per card)" -> "Launch one agent per card (run_in_background)";
    "Launch one agent per card (run_in_background)" -> "Review agent output";
    "Move card Doing → Reviewing" -> "Triage automated review comments on PRs";
}
```

### Worktree Creation

If the repo has `scripts/create-worktree.sh`, use it:
```bash
scripts/create-worktree.sh feat/<short-name>
```

Otherwise, create manually and let the agent set up the environment from project context:
```bash
git worktree add .worktrees/feat/<short-name> -b feat/<short-name>
```

### Review Checklist

When reviewing agent output, check for:

- **Architecture compliance** — services don't import HTTP concepts, routers don't contain logic, contracts follow repo conventions
- **Write-path completeness** — if the card creates or updates data, verify the full chain through all layers
- **Test coverage** — every business rule in the card's description has a corresponding test
- **Quality gates passing** — lint, type-check, tests all green

### PR Format

PR descriptions must follow the format in `CLAUDE.md` / `~/.claude/CLAUDE.md`. At minimum:
```
## What?
[From the Trello card]

## Why?
[From the Trello card]

## Changes
...

## Test Plan
- [ ] ...
```

### Worktree Cleanup

After merging:
```bash
git worktree remove .worktrees/feat/<short-name>
git branch -d feat/<short-name>
```

## Rules

| Rule | Why |
|------|-----|
| Cards define PR scope — implement everything in the Definition of Done | One card = one PR, no partial implementations |
| Never move a card to Done yourself — that happens after merge | Reviewing and Done are separate columns |
| Never alias the `trello.sh` path to a variable | Breaks the auto-approve hook |
| No comments before `trello.sh` in bash commands | Also breaks auto-approval |
| Architecture rules come from repo docs — follow them, don't reinvent | `AGENTS.md` and `docs/` are authoritative |
| Keep Trello updated promptly | Move cards between columns and tick checklist items as work progresses |
| When ready cards share files, don't parallelise them | Split the wave or execute conflicting cards sequentially |
| If no cards are ready, inform the user and terminate | Do not invent work |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Dispatching agents without gathering shared context first | Read implementation files and include verbatim code in prompts |
| Treating "Done on Trello" as "merged to main" | Always verify with `git log` or `git branch -r` |
| Parallelising cards that touch the same files | Analyse file conflicts before grouping into a wave |
| Letting agents handle git operations | Agents write code only — orchestrator owns git, PRs, Trello |
| Skipping automated review comment triage | Check each PR for bot comments, reply with rationale, apply valid fixes |
| Moving cards straight to Done after PR creation | Cards go to Reviewing first, then Done after merge |

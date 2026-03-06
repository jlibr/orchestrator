# Orchestrator Plugin

Multi-agent pipeline orchestration for Claude Code. Compose agents into phased workflows with quality gates, iteration control, and artifact management.

## What This Does

- **Auto-generates domain agents and knowledge slices** from your idea and codebase
- **Coordinates multiple agents** through sequential/parallel phases
- **Manages build-review loops** with bounded iteration (stop hook)
- **Routes issues between agents** via a file-based issue bus
- **Persists all artifacts** in session directories for auditability
- **Coexists with taskmaster** — stop hook only activates during active pipelines

## Installation

```bash
git clone https://github.com/jlibr/orchestrator.git
cd orchestrator
bash install.sh
```

This copies the plugin to `~/.claude/plugins/orchestrator/` and registers `/pipe`, `/pipe-status`, and `/pipe-cancel` as commands.

## Quick Start

Just describe what you want to build:

```
/pipe "build a REST API for user management"
```

The orchestrator handles everything:
1. Challenges your idea (5 gates)
2. Writes a spec (requirements, design, tasks)
3. Explores the codebase for context
4. Auto-generates the right agents, knowledge slices, and pipeline config
5. Builds, reviews, iterates until PASS

## Commands

| Command | What it does |
|---------|-------------|
| `/pipe "idea"` | Full autonomous pipeline from idea to build |
| `/pipe config.yaml` | Run a pre-configured pipeline (power user) |
| `/pipe path/to/spec/` | Use existing spec from `/loop-spec` (skips challenge + specify) |
| `/pipe resume` | Resume an interrupted pipeline |
| `/pipe-status` | Show current pipeline state |
| `/pipe-cancel` | Cancel active pipeline |

## Two Modes

**Mode 1: `/pipe "idea"` (default)** — Fully autonomous. The orchestrator generates everything: domain agents, knowledge slices, pipeline config. You approve the spec and generated infrastructure, then it builds.

**Mode 2: `/pipe config.yaml` (power user)** — You define the pipeline config, agents, and knowledge slices yourself. Useful for reusable pipelines or fine-grained control. Copy from `templates/` to get started.

## Built-in Agents

**Infrastructure agents** (used in every pipeline):

| Agent | Role | Model |
|-------|------|-------|
| `pipe-explorer` | Codebase discovery and context mapping | sonnet |
| `pipe-researcher` | Build-vs-buy analysis, web research | haiku |
| `pipe-reviewer` | Quality review, PASS/FAIL verdicts | inherit |

**Specialized build agents** (used when applicable):

| Agent | Role | Model |
|-------|------|-------|
| `ui-architect` | Design research, visual spec, component patterns | sonnet |
| `ui-builder` | Frontend implementation from design spec | sonnet |

**QA agents** (used in test/QA sweep phases):

| Agent | Role | Model |
|-------|------|-------|
| `qa-tester` | Automated e2e testing via browser automation | sonnet |
| `qa-design` | Design spec compliance — tokens, spacing, typography | sonnet |
| `qa-ux` | UX heuristics — states, responsive, touch targets | sonnet |
| `qa-security` | Auth, XSS, CSRF, RLS, env vars | sonnet |
| `qa-content` | Microcopy, placeholders, grammar, terminology | haiku |
| `qa-accessibility` | WCAG 2.1 AA — contrast, focus, ARIA, keyboard nav | sonnet |

## Architecture

```
/pipe "idea"
    ├── Phase 0: Setup (session dirs, state file)
    ├── Phase 1: Challenge (5 gates with user)
    ├── Phase 2: Specify (requirements, design, tasks)
    ├── Phase 3: Explore (codebase context)
    ├── Phase 3.5: Design (ui-architect — optional, for UI/frontend work)
    ├── Phase 4: Generate (check learning store → agents, knowledge, config)
    ├── Phase 5: Build (dispatch domain + standing agents)
    ├── Phase 5.5: Test (qa-tester — optional, for deployed web apps)
    ├── Phase 6: Review (quality gate, PASS/FAIL)
    │       └── FAIL → back to Phase 5 (bounded by max_cycles)
    └── Phase 7: Wrap-up (summary, retrospective → learning store)
```

Each completed pipeline writes a retrospective to the learning store. Future runs consult it in Phase 4, reusing agent configs and knowledge that produced PASS verdicts. The system gets better with use.

The orchestration logic lives in the `/pipe` command markdown — it's a prompt, not a code engine. The reusable infrastructure is: state management, setup/teardown, stop hook, agent conventions, and artifact/issue bus formats.

## File Structure

```
orchestrator/
├── .claude-plugin/plugin.json    # Plugin manifest
├── agents/                       # Built-in support agents
├── commands/                     # /pipe, /pipe-status, /pipe-cancel
├── hooks/                        # Stop hook for iteration control
├── scripts/                      # Setup/teardown scripts
├── knowledge/                    # How-to guides and conventions
├── learning/                     # Retrospectives from past runs (self-learning)
└── templates/                    # Starters for Mode 2 (manual config)
```

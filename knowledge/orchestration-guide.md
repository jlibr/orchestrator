# Orchestration Guide

How to use the orchestrator plugin for multi-agent pipelines.

## Quick Start

**Mode 1 (recommended): Just describe what you want.**
```
/pipe "build a tutoring platform with spaced repetition"
```
The orchestrator handles everything — challenge gates, spec, codebase exploration, agent generation, build, review. You approve at key checkpoints.

**Mode 2 (power user): Define your own pipeline.**
1. Create a `pipeline.yaml` in your project root (copy from `templates/pipeline-config.yaml`)
2. Define domain agents (copy from `templates/domain-agent.md`)
3. Add knowledge slices if needed (copy from `templates/knowledge-slice.md`)
4. Run `/pipe pipeline.yaml`

## Creating a Pipeline Config

The pipeline config declares phases, agents, and quality gates. The orchestrator reads it and dispatches accordingly.

### Minimal Config

```yaml
name: my-project
description: "Build a thing"
type: build
max_cycles: 3

phases:
  - id: build
    description: "Build the thing"
    agents:
      - agent: my-builder
        model: sonnet
    gate:
      agent: pipe-reviewer
      pass_threshold: "PASS"
      fail_action: retry
```

### Phase Structure

Each phase has:
- `id` — unique identifier, used in `depends_on` references
- `description` — what this phase accomplishes
- `agents` — list of agents to dispatch
- `output` — directory for artifacts (relative to session dir)
- `skip_if` — condition to skip (evaluated as a string match against project state)
- `gate` — optional quality gate after the phase

### Agent Config within a Phase

```yaml
agents:
  - agent: agent-name           # Must match an agent .md file name
    model: sonnet               # sonnet | haiku | opus | inherit
    parallel: true              # Can run multiple instances
    parallel_with: other-agent  # Runs simultaneously with named agent
    depends_on: [phase-id]      # Wait for these phases
    output: artifacts/subdir/   # Where this agent writes
    requires_approval: true     # Ask user before executing
```

### Quality Gates

Gates run a reviewer agent after a phase and decide whether to iterate:

```yaml
gate:
  agent: pipe-reviewer          # Or a custom reviewer
  model: inherit
  pass_threshold: "PASS"
  fail_action: retry            # retry | stop | skip
  max_gate_cycles: 2            # Independent of top-level max_cycles
```

### Model Routing

Override individual agent models for cost optimization:

```yaml
model_routing:
  haiku: [lightweight-agent-1, lightweight-agent-2]
  sonnet: [complex-agent-1]
```

## Standing Agents (Built-in)

The plugin includes 11 standing agents that are reusable across any project:

**Infrastructure agents** (used in every pipeline):

| Agent | Phase | Role |
|-------|-------|------|
| `pipe-explorer` | Explore | Codebase discovery and context mapping |
| `pipe-researcher` | Explore (background) | Build-vs-buy analysis, web research |
| `pipe-reviewer` | Review | Quality gate, PASS/FAIL verdicts |

**Specialized build agents** (used when applicable):

| Agent | Phase | Role |
|-------|-------|------|
| `ui-architect` | Design | Design research, visual spec, component patterns |
| `ui-builder` | Build | Frontend implementation from design spec |

**QA agents** (used in test/QA sweep phases):

| Agent | Phase | Role | Model |
|-------|-------|------|-------|
| `qa-tester` | Test | Automated e2e testing via browser automation | sonnet |
| `qa-design` | QA Sweep | Design spec compliance — color tokens, spacing, radius, typography | sonnet |
| `qa-ux` | QA Sweep | UX heuristics — empty/error/loading states, responsive, touch targets | sonnet |
| `qa-security` | QA Sweep | Auth, API key exposure, XSS, CSRF, Supabase RLS, env vars | sonnet |
| `qa-content` | QA Sweep | Microcopy, placeholder text, error messages, grammar, terminology | haiku |
| `qa-accessibility` | QA Sweep | WCAG 2.1 AA — contrast, focus, keyboard nav, ARIA, semantic HTML | sonnet |

Standing agents are dispatched by the orchestrator when needed. Build agents are optional — only used when the pipeline has frontend/UI work. QA agents run in the test/QA sweep phase after builds complete. They can run in parallel and produce independent reports.

## Domain Agents

Domain agents are the workers that do project-specific tasks.

**Mode 1 (auto):** The orchestrator generates domain agents automatically in Phase 4 based on the spec and codebase context. They're written to `.claude/pipeline/sessions/{session}/agents/`. Standing agents (above) are NOT regenerated — only project-specific roles get new agents.

**Mode 2 (manual):** Create agents yourself using `templates/domain-agent.md`. Place in the project's `.claude/agents/` or wherever your pipeline config references them.

### Agent Structure (both modes)

1. **Step 0: Load Knowledge** — Read knowledge slices and project CLAUDE.md
2. **Step 1: Read Input** — Consume artifacts from previous phases
3. **Step 2: Execute** — Do the domain-specific work
4. **Step 3: Write Output** — Produce artifacts for downstream consumption
5. **Step 4: Verify** — Self-check (run tests, validate output)
6. **Step 5: Issue Detection** — Check for cross-agent problems

### Agent Naming Convention

`{project}-{role}` — e.g., `learntrellis-lesson-author`, `webapp-frontend-dev`

## Knowledge Slices

Knowledge slices give agents domain expertise they wouldn't otherwise have. They contain:
- **Rules** — absolute constraints
- **Patterns** — preferred approaches
- **Common mistakes** — known failure modes
- **Reference** — schemas, APIs, examples

**Mode 1 (auto):** Generated alongside agents in Phase 4, written to `.claude/pipeline/sessions/{session}/knowledge/`. Derived from the spec and codebase context.

**Mode 2 (manual):** Create using `templates/knowledge-slice.md`. Place wherever your pipeline config or agent Step 0 references them.

## Issue Bus

The issue bus is a file-based communication channel between agents. When Agent A finds a problem that Agent B should fix, it writes an issue file:

```
artifacts/issues/{from}-to-{to}-{timestamp}.md
```

The orchestrator scans for open issues after each phase and routes them to target agents in subsequent phases. Issues have types (configurable per project), severity levels, and a max redispatch count to prevent infinite loops.

## Pipeline Types

- **`build`** — One-shot execution. Explore → Build → Review → Done. For creating new features or projects.
- **`session`** — Repeated per interaction. Each user interaction triggers a pipeline run. For runtime systems like tutoring or content generation.

## Tips

1. Start with fewer phases and agents. Add complexity only when needed.
2. Use `pipe-explorer` first — it gives all downstream agents better context.
3. Set `max_cycles` to 2-3. More iterations rarely improve quality.
4. Use `requires_approval: true` for destructive or external-facing phases.
5. Put expensive agents (opus) only where quality justifies cost.
6. Knowledge slices are reusable across agents — share them.

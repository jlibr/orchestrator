# Pipeline Conventions Reference

Standard formats for artifacts, issue bus entries, state management, and review output used by the orchestrator plugin.

## Directory Layout

```
.claude/pipeline/
├── state.yaml                          # Active pipeline state (single file, one pipeline at a time)
└── sessions/
    └── {session-name}/
        ├── spec/                       # Requirements, design docs, challenge output
        │   ├── challenge.md            # Gate responses from /pipe Mode 1
        │   ├── requirements.md         # Functional + non-functional requirements
        │   ├── design.md               # Architecture decisions
        │   └── tasks.md               # Ordered task list
        ├── context/                    # Explorer + researcher output
        │   ├── context.md             # Codebase analysis
        │   └── research.md            # Build-vs-buy analysis
        ├── agents/                     # Auto-generated domain agents (Mode 1)
        │   └── {project}-{role}.md    # One per build role
        ├── knowledge/                  # Auto-generated knowledge slices (Mode 1)
        │   └── {domain}.md            # Domain rules, patterns, references
        ├── artifacts/
        │   ├── design/                # ui-architect output (design-spec.md)
        │   ├── qa/                    # qa-tester output (test-report.md, screenshots/, videos/)
        │   ├── {agent-id}/            # Per-agent output directories
        │   └── issues/                # Cross-agent issue files
        ├── reviews/
        │   └── cycle-{N}.md           # Reviewer output per cycle
        └── pipeline.yaml              # Auto-generated pipeline config (Mode 1)
```

**Path convention:** All auto-generated infrastructure (agents, knowledge slices, pipeline config) lives inside the session directory. This keeps sessions self-contained and isolated from each other. Mode 2 (manual config) can reference agents anywhere — typically in the project's `.claude/agents/` directory.

## State File Format (`state.yaml`)

```yaml
status: idle                    # idle | specifying | exploring | designing | generating | building | testing | reviewing | done | failed | cancelled
session_name: my-session
pipeline_config: ./pipeline.yaml  # Set at setup (Mode 2) or after auto-gen (Mode 1)
cycle: 0                        # Current review cycle (0 = first build)
max_cycles: 3
max_duration: 60                # Wall-clock timeout in minutes (stop hook enforces)
current_phase: ""
current_agent: ""
started_at: "2026-03-04T12:00:00Z"
phases_completed: []            # List of phase IDs
agent_status: {}                # {agent-id: pending | running | success | failed}
gate_verdicts: {}               # {phase-id: PASS | FAIL}
redispatch_count: {}            # {"agent-a->agent-b": N}
issues_open: 0
issues_resolved: 0
tokens_used: 0                  # Cumulative token count across all agents
worktree_path: ""
branch_name: ""
pr_url: ""
pr_number: ""
```

### Atomic State Writes

State.yaml must never be written directly by agents or `sed -i`. Always use the atomic write script:

```bash
# Full write (pipe content in)
echo "$NEW_STATE" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/write-state.sh"

# Partial update (key=value args)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/write-state.sh" status=building current_phase=build
```

The script writes to a temp file then `mv`s into place. A PreToolUse hook blocks direct Write/Edit to state.yaml during active pipelines.

### Cost Ledger Format

File: `sessions/{session}/cost-ledger.md`

```markdown
| Timestamp | Agent | Phase | Model | Tokens | Cycle |
|-----------|-------|-------|-------|--------|-------|
| 2026-03-04T12:05:00Z | pipe-explorer | explore | sonnet | 8500 | 0 |
| 2026-03-04T12:10:00Z | app-builder | build | sonnet | 25000 | 0 |
```

### Checkpoint Format

File: `sessions/{session}/checkpoint.md`

```markdown
# Checkpoint: {phase just completed}
Timestamp: {now}
Phases done: {list}
Agents completed: {list with status}
Current cycle: {N}/{max}
Key decisions: {1-2 line summary}
Next action: {what the orchestrator should do next}
```

Written after every phase transition. Read by `/pipe resume` for rich context beyond state.yaml.

### Status Transitions

```
idle → specifying → exploring → designing → generating → building → testing → reviewing → done
                                                           ↑                      |
                                                           └──── (FAIL) ──────────┘  (cycle < max_cycles)
                                                                                  |
                                                                                  └── done (cycle >= max_cycles OR PASS)

Any state → cancelled (user cancellation)
Any state → failed (unrecoverable error)

Note: designing and testing are optional — skipped when not applicable (e.g., backend-only pipelines skip designing, non-web pipelines skip testing).
```

**`status` vs `current_phase`:** `status` is the broad pipeline mode (what the stop hook checks). `current_phase` is the granular phase ID from the pipeline config (e.g., `explore`, `design`, `build`, `test`). Both exist in state.yaml. `status` controls iteration logic; `current_phase` tracks progress within phases.

## Issue Bus Format

Filename: `{from-agent}-to-{to-agent}-{YYYYMMDD-HHmmss}.md`

```yaml
---
from: agent-a
to: agent-b
type: MISMATCH                  # Project-defined types
severity: CRITICAL | HIGH | MEDIUM
status: open                    # open | resolved | deferred
created: 2026-03-04
---
## Evidence
[Concrete code/data showing the problem — file paths and line numbers]

## Impact
[What breaks or degrades if not fixed]

## Suggested Fix
[Specific action the target agent should take]
```

### Default Issue Types

- **MISMATCH** — Two agents produced incompatible outputs (e.g., API contract mismatch)
- **MISSING** — Required output from one agent is absent
- **CONFLICT** — Two agents modified the same file or resource
- **DESIGN_DEVIATION** — Implementation doesn't match the design spec (ui-builder vs ui-architect)

Projects can define additional types in `pipeline.yaml` under `issue_bus.types`.

### Redispatch Rules

- Each agent pair has a redispatch counter: `"agent-a->agent-b": N`
- Default max redispatch: 2 (configurable via `issue_bus.max_redispatch`)
- When limit is reached, issue is marked `deferred` and reported to user

## Review Output Format

File: `reviews/cycle-{N}.md`

```markdown
VERDICT: PASS | FAIL

# Review — Cycle {N}
Reviewed: {timestamp}
Session: {session-name}
Artifacts reviewed: {count}

## Summary
[2-3 sentence assessment]

## Findings

### CRITICAL (blocks shipping)
- [ ] {Finding with file:line and fix needed}

### MAJOR (should fix before merge)
- [ ] {Finding}

### MINOR (nice to have)
- [ ] {Finding}

### NITS (style only)
- [ ] {Finding}

## Spec Compliance Checklist
- [x] Requirement — met
- [ ] Requirement — not met: {reason}

## Test Results
{Output from automated tests}

## Cross-Agent Issues
{Issues written to the issue bus this cycle}

## Recommendation
{If FAIL: what to fix. If PASS: optional improvements.}
```

### Verdict Rules

- Any CRITICAL finding → automatic FAIL
- VERDICT must be on the FIRST LINE of the file (the stop hook parses it)
- PASS means "shippable" — not perfect, just meets the bar

## Artifact Conventions

### Naming

Artifacts are files produced by agents. They go in `artifacts/{agent-id}/` unless the pipeline config specifies a different `output` path.

### Handoff

When Agent A produces output that Agent B consumes:
1. Agent A writes to its output directory
2. The orchestrator passes the output path to Agent B's prompt
3. Agent B reads from Agent A's output directory

### Persistence

All artifacts persist in the session directory. Nothing is ephemeral. This allows:
- Post-mortem analysis of failed pipelines
- Resuming interrupted sessions
- Comparing output across review cycles

## Learning System

The orchestrator learns from past runs via retrospectives.

### How It Works

1. **Write:** After every pipeline completion (Phase 7), a retrospective is written to:
   - `sessions/{session}/retrospective.md` — session-local copy
   - `${CLAUDE_PLUGIN_ROOT}/learning/{project}-{session}.md` — persistent learning store

2. **Read:** In Phase 4 (Generate), before creating agents/slices, the orchestrator scans the learning store for:
   - Same project (exact match — reuse agent configs that worked)
   - Same tech stack (similar framework — reuse knowledge slices)
   - Same problem domain (similar build type — reuse pipeline structure)

3. **Adapt:** Matched retrospectives inform generation:
   - Agent configs that got PASS are adapted, not rebuilt from scratch
   - Known anti-patterns are pre-loaded into knowledge slices
   - Pipeline structure (agent count, parallelism, gates) follows what worked before

### Learning Store Location

`${CLAUDE_PLUGIN_ROOT}/learning/` — persists across all sessions and projects. Files are named `{project}-{session}.md`.

### What Gets Captured

- Effective agent configurations (model, tools, key instructions)
- Knowledge slice rules that prevented errors
- Recurring failure patterns and their fixes
- User overrides (scope changes, agent modifications)
- Issue bus friction patterns between agent pairs

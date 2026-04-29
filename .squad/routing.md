# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Architecture & design | McClane | App structure, migration strategy, patterns, decisions |
| Frontend / AngularJS / Angular | Argyle | UI components, views, client-side logic, CSS/HTML |
| Backend / .NET / C# / SQL | Karl | APIs, controllers, EF data access, database schema |
| Azure / deployment / infra | Theo | App Service, Azure SQL, Blob Storage, CI/CD, IaC |
| Code review | McClane | Review PRs, check quality, architectural consistency |
| Scope & priorities | McClane | What to build next, trade-offs, decisions |
| File upload (full-stack) | Karl + Argyle | Backend blob handling + frontend upload UI |
| Migration planning | McClane + Theo | Strategy docs, sequencing, Azure readiness |
| Session logging | Scribe | Automatic — never needs routing |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | McClane |
| `squad:mcclane` | Architecture/review tasks | McClane |
| `squad:argyle` | Frontend work | Argyle |
| `squad:karl` | Backend work | Karl |
| `squad:theo` | Cloud/DevOps work | Theo |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, **McClane** triages it — analyzing content, assigning the right `squad:{member}` label, and commenting with triage notes.
2. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for McClane's review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. McClane handles all `squad` (base label) triage.

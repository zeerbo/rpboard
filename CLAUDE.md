# CLAUDE.md

## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: one `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

### Data transfer

Touching the data model — adding a table, adding a field a user's data depends on — means extending `AppSnapshot` and its round-trip test, or the new data is silently dropped by "Trasferisci dati". See [ADR-0007](docs/adr/0007-app-snapshot-data-transfer.md).

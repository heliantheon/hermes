# Hermes

This repository owns Helios identity persistence, provisioning, and relationship data.

## Boundaries

- Authentication flows and token issuance belong to Aegis.
- Shared gRPC contracts belong to `heliannuuthus/proto`.
- Reusable guards belong to `heliannuuthus/aegis-go`.
- Domain-independent infrastructure belongs to `heliannuuthus/common`.

## Commands

```bash
make test
make lint
make build
make run
```

## Verification

- Run all Go tests after model, query, or gRPC changes.
- Keep SQL schema changes compatible with existing data or document the required migration.
- Regenerate clients in the Proto repository when a contract changes.

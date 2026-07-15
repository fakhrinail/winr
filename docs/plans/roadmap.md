# Winr delivery roadmap

Winr is delivered in review-sized phases under a zero-cost-first constraint.
Each checkpoint is implemented, validated, documented, and reviewed before the
next checkpoint starts.

## Phases

1. **Local Supabase foundation** — reproducible tooling, schema, integrity,
   authorization, private Storage, bootstrap data, notification schema, and tests.
2. **Hosted Supabase and authentication** — free hosted project, magic links,
   environment configuration, and hosted policy verification.
3. **PWA and reliable capture** — React shell, IndexedDB outbox, and offline-first
   win creation.
4. **Reflection and organization** — timeline, filters, editing, categories,
   tags, search, and export.
5. **Multiple photos** — client compression, reliable uploads, signed retrieval,
   and quota controls.
6. **Reminders and launch hardening** — web push, scheduled reminders,
   accessibility, deployment, monitoring, and backup procedures.

## Delivery status

| Phase | Status |
| --- | --- |
| 1A Repository and tooling | Implemented; awaiting review |
| 1B Core schema | Implemented; awaiting review |
| 1C Integrity rules and indexes | Not started |
| 1D Row Level Security | Not started |
| 1E Private photo storage | Not started |
| 1F Profile bootstrap and starter categories | Not started |
| 1G Notification schema | Not started |
| 1H Types, tests, and handoff | Not started |
| Phases 2–6 | Not started |

## Architecture boundary

The PWA will communicate directly with Supabase under Row Level Security. Winr
does not require a dedicated backend server for v1. Scheduled or privileged
operations will run in Supabase Edge Functions, and service-role credentials
will never be exposed to the browser.


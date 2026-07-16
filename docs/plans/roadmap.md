# Winr delivery roadmap

Winr is delivered in review-sized phases under a zero-cost-first constraint.
Each checkpoint is implemented, validated, documented, and reviewed before the
next checkpoint starts.

## Phases

1. **Local Supabase foundation** — reproducible tooling, schema, integrity,
   authorization, bootstrap data, notification schema, and tests. Photo Storage
   is explicitly deferred.
2. **Hosted Supabase and authentication** — free hosted project, magic links,
   environment configuration, and hosted policy verification.
3. **Text-only PWA** — React shell, IndexedDB outbox, offline-first capture,
   timeline, editing, categories, tags, search, and export.
4. **Reminders and launch hardening** — push-subscription UI, web push, one
   hourly scheduled reminder job, accessibility, deployment, monitoring, and
   backup procedures.
5. **Deferred photos** — private Storage, client compression, reliable uploads,
   signed retrieval, and quota controls only after the core app is validated.

## Delivery status

| Phase | Status |
| --- | --- |
| 1A Repository and tooling | Complete |
| 1B Core schema | Complete |
| 1C Integrity rules and indexes | Complete |
| 1D Row Level Security | Complete |
| 1E Private photo storage | Deferred until after text-only launch |
| 1F Profile bootstrap and starter categories | Complete |
| 1G Notification foundation | Complete |
| 1H Types, tests, and handoff | Next |
| Phases 2–5 | Not started |

## Architecture boundary

The PWA will communicate directly with Supabase under Row Level Security. Winr
does not require a dedicated backend server for v1. Scheduled or privileged
operations will run in Supabase Edge Functions, and service-role credentials
will never be exposed to the browser.

## Sequencing decision

The first usable release excludes photos. Keep the existing `win_assets` table
and its RLS dormant, but do not create a Storage bucket or build image workflows.
Complete profile bootstrap and notification data first, then hosted auth and the
text-only PWA. Actual push delivery follows the PWA because a real browser service
worker and user-generated push subscription are required.

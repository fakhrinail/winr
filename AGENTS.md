# Winr project instructions

## Product direction

Winr is a self-esteem and accountability PWA for recording personal wins and
revisiting them later. The primary product requirement is capturing a text win
in under ten seconds without requiring a category or tags.

The first usable release deliberately excludes photos. The existing
`win_assets` schema remains dormant so photos can be added later without
redesigning the core model. Do not implement Supabase Storage, image processing,
photo UI, or upload synchronization until the photo phase is explicitly resumed.

## Architecture

- React/TypeScript PWA communicates directly with Supabase.
- Supabase Auth establishes identity.
- Postgres constraints and triggers enforce durable data integrity.
- Row Level Security is the authorization boundary for browser access.
- IndexedDB will provide an offline outbox for text captures.
- Supabase Edge Functions and Cron handle trusted scheduled work such as push
  reminders.
- There is no dedicated application server in v1.
- Never expose or commit service-role credentials.

## Cost constraint

Keep infrastructure at $0/month through personal use and the first tens or
hundreds of users. Prefer the Supabase Free plan, static hosting, local image-free
data, one shared Cron schedule, and no paid APIs. Do not enable automatic
overage billing or introduce a paid dependency without explicit approval.

## Delivery and review workflow

Work in small checkpoints. For each checkpoint:

1. Implement only the approved checkpoint.
2. Run a clean migration reset, schema lint, and targeted rollback-only tests.
3. Update the relevant plan document with status and results.
4. Report changed behavior, files, decisions, and test results.
5. Stop for review before starting the next checkpoint.

Preserve user-authored changes and do not create Git commits unless explicitly
requested. Migrations are the schema source of truth; do not rely on
Dashboard-only schema changes.

## Current implementation status

- 1A repository and local Supabase tooling: implemented.
- 1B core schema: implemented.
- 1C integrity rules, indexes, ownership checks, and timestamp triggers:
  implemented and tested.
- 1D RLS for profiles, wins, categories, tags, win tags, and asset metadata:
  implemented and tested.
- 1E private photo Storage: explicitly deferred.
- 1F profile bootstrap and starter categories: implemented and tested.
- 1G notification foundation: implemented and tested.
- 1H generated types, pgTAP consolidation, and backend handoff: next.

After Phase 1, connect a hosted Supabase Free project, configure magic-link
authentication, build the text-only PWA, then implement actual web-push delivery.

## Database invariants

- All application data is private to its owner; anonymous access is denied.
- A win requires nonblank text but category and tags are optional.
- Category and tag names are unique per user after trimming and lowercasing.
- Ownership cannot be transferred by updating `user_id`.
- Cross-owner win/category, win/tag, and win/asset relationships are rejected.
- Client-generated win UUIDs support idempotent offline synchronization.
- Category deletion uncategorizes wins; win/tag deletion cascades dependent join
  metadata.
- Win-tag links are detached and recreated rather than updated.
- Existing asset records may only be reordered; photo identity is immutable.

## Local commands

```bash
npm run supabase:start
npm run supabase:reset
npm run supabase:lint
npm run supabase:test:1c
npm run supabase:test:1d
npm run supabase:test:1f
npm run supabase:test:1g
npm run supabase:stop
```

The local Supabase Studio is available at `http://127.0.0.1:54323` while the
stack is running. Tests must use transactions and roll back their fixtures.

## Planning sources

- `docs/plans/roadmap.md` contains the phase sequence and delivery status.
- `docs/plans/phase-01-supabase-foundation.md` contains checkpoint-level backend
  decisions and validation results.

# Phase 1: Local Supabase foundation

## Goal

Build a reproducible, locally testable Supabase backend in small checkpoints.
The local migrations are the source of truth; dashboard-only schema changes are
not part of the workflow.

## Review workflow

After every checkpoint:

1. Run its targeted validation.
2. Record results in this document.
3. Present the changed files and decisions for review.
4. Stop until the checkpoint is approved.

## 1A: Repository and tooling

Status: **Implemented; awaiting review**

Included:

- Node 22 project metadata.
- Supabase CLI pinned as a local development dependency.
- Local Supabase configuration and an intentionally empty seed file.
- Commands for local start, stop, status, reset, and database linting.
- Secret-safe environment template and ignore rules.

Validation results (2026-07-15):

- Supabase CLI `2.109.1` installed from the lockfile.
- `npm install` reported zero vulnerabilities.
- The local Supabase stack started successfully through Docker.
- Secret-bearing `.env` files and Supabase temporary state are ignored.

## 1B: Core schema

Status: **Implemented; awaiting review**

Included entities:

- `profiles`: application data for a Supabase Auth user.
- `categories`: optional broad life domains owned by one user.
- `tags`: reusable descriptive labels owned by one user.
- `wins`: client-ID-based entries with optional category and occurrence time.
- `win_tags`: many-to-many links between wins and tags.
- `win_assets`: ordered metadata for multiple privately stored photos.

Deliberately deferred:

- Advanced validation and ownership-consistency constraints.
- Query indexes beyond primary keys.
- Automatic `updated_at` triggers.
- Row Level Security and grants.
- Storage bucket creation and policies.
- Profile bootstrap and starter categories.
- Notification tables.
- Generated TypeScript types and the full database test suite.

Validation results (2026-07-15):

- A clean `supabase db reset` applied the migration and seed file successfully.
- All six expected tables were found in the local `public` schema.
- `supabase db lint --local` reported no schema errors.
- `git diff --check` reported no whitespace errors.

## 1C: Integrity rules and indexes

Status: **Implemented; awaiting review**

Included:

- Nonblank and positive-value checks contributed collaboratively.
- Case- and whitespace-insensitive category/tag uniqueness per user.
- Unique photo positions per win and unique Storage object paths.
- Indexes for timeline, category, tag, category-picker, and asset-usage queries.
- Immutable ownership and same-owner checks across related records.
- Automatic `updated_at` maintenance.
- Existing foreign-key deletion behavior retained: category deletion uncategorizes
  wins; win and tag deletion cascades their dependent metadata.

Validation results (2026-07-15):

- A clean database reset applied both migrations successfully.
- Local schema lint reported no errors.
- Transactional tests reject normalized duplicates, cross-owner relationships,
  and duplicate photo positions.
- Transactional tests verify timestamp maintenance and intended deletion behavior.
- The behavior suite rolls back and leaves no test fixtures behind.

## Remaining checkpoints

- 1D: Row Level Security.
- 1E: private photo storage.
- 1F: profile bootstrap and starter categories.
- 1G: notification schema.
- 1H: generated types, automated tests, and handoff documentation.

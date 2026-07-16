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

Status: **Complete**

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

Status: **Complete**

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

Status: **Complete**

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

## 1D: Row Level Security

Status: **Complete**

Authorization matrix:

| Resource | Anonymous | Owner | Other user | Notes |
| --- | --- | --- | --- | --- |
| `profiles` | None | Read; update timezone/onboarding | None | Trusted bootstrap creates profiles in 1F |
| `wins` | None | Create, read, update, delete | None | Cannot change ownership |
| `categories` | None | Create, read, update, delete | None | Cannot change ownership |
| `tags` | None | Create, read, update, delete | None | Cannot change ownership |
| `win_tags` | None | Read, attach, detach | None | Delete and recreate rather than update |
| `win_assets` | None | Create, read, update, delete | None | Storage object policies are deferred with photos |

Implementation:

- Anonymous receives no table privileges.
- Authenticated users can select only their own profile.
- Authenticated users can update only their own `timezone` and
  `onboarding_completed_at` fields.
- Profile insert and delete remain restricted to trusted backend operations.
- A rollback-only two-user test verifies grants, column permissions, row
  visibility, owner-only updates, and automatic timestamps.
- Wins, categories, tags, and asset metadata use owner-scoped CRUD policies.
- Asset identity is immutable through column grants; clients may only reorder
  existing asset metadata.
- Win-tag links derive authorization through both their win and tag; links are
  detached and recreated rather than updated.
- Repeatable two-user tests cover positive and negative access for every table.

## Remaining checkpoints

- 1E: private photo Storage — **deferred until after the text-only launch**.
- 1F: profile bootstrap and starter categories — **complete**.
- 1G: notification foundation — **complete**.
- 1H: generated types, pgTAP consolidation, and backend handoff — **next**.

## 1F: Profile bootstrap and starter categories

Status: **Complete**

Implementation:

- An `auth.users` insert trigger invokes a trusted `security definer` routine.
- Every new user receives one profile with `UTC` as the safe default timezone.
- Every new user receives Health, Work & Learning, Relationships, Personal
  Growth, and Everyday Life in a stable display order with starter colors.
- The routine is idempotent: trusted retries preserve one profile and five
  categories.
- Anonymous and authenticated API roles cannot execute the trusted routines.
- Deleting the Auth user cascades their profile and starter categories.

Validation results (2026-07-16):

- A clean database reset applied all six migrations successfully.
- Local schema lint reported no errors.
- Existing 1C integrity and 1D authorization suites remain green after automatic
  profile/category creation was introduced.
- The 1F suite verifies initial bootstrap, exact starter data, safe retries,
  independent users, API-role denial, RLS visibility, and Auth deletion cascades.
- Every test rolls back its fixtures.

## 1G: Notification foundation

Status: **Complete**

Implementation:

- Preferences separate the 20:00 evening log reminder from weekly and monthly
  07:00 morning recaps; every setting defaults to disabled.
- Reminder and recap times support 15-minute increments, while timezone remains
  owned by the profile.
- Win text is hidden from notification payloads by default.
- Each browser installation has its own private push-subscription row; browser
  roles cannot modify server delivery-health fields.
- A server-only delivery table claims each user/type/period once to prevent
  duplicate reminders and recaps.
- Existing profiles are backfilled and future Auth users receive preferences
  through the retry-safe bootstrap.
- Actual Web Push, VAPID configuration, Cron, recap selection, and delivery are
  deferred until the PWA exists.

Validation results (2026-07-16):

- A clean database reset applied all seven migrations successfully.
- Local schema lint reported no errors.
- The aggregate 1C–1G backend suite passes without leaving fixtures.
- Tests verify bootstrap defaults and retries, quarter-hour time constraints,
  unique endpoints, unique delivery claims, valid notification types, protected
  delivery-health fields, multiple devices, and two-user RLS isolation.

## Revised delivery boundary

The first usable backend and PWA exclude photos. The existing `win_assets` table,
integrity rules, and RLS remain in place but dormant. Phase 1 does not create the
`win-photos` bucket or Storage policies.

After 1F–1H, the next sequence is:

1. Link and validate a hosted Supabase Free project.
2. Configure magic-link authentication.
3. Build the text-only PWA with offline capture and reflection.
4. Register real browser push subscriptions and implement scheduled delivery.
5. Return to private photo Storage only after the core product is validated.

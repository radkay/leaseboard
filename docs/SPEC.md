# Leaseboard - Build Spec

**Owner:** Ron Radkay · **Build window:** weekend of Nov 21-22, 2026 · **Status:** not started

## 1. Why this exists

Leaseboard is a portfolio project showing that Ron can direct AI coding agents to ship
production-quality software in stacks he has not shipped before: **Ruby on Rails, Elixir/Phoenix
and Sanity**. These are common choices at product studios and agencies, alongside TypeScript, Next.js,
React, Postgres and Redis, deployed to platforms like Render.

The app matters less than the **process record**: decisions, tests, CI, and what Ron caught in
review. Those artifacts are the exhibit.

## 2. Hard rules

- **Synthetic data only.** No code, data, client names, schemas or documents from any employer or client.
  The rental-property domain is general industry knowledge; everything else is built fresh.
- **Boring technology.** Each framework does what it's best at. Platform-as-a-service hosting.
  No custom infrastructure, no Kubernetes, no microservice sprawl.
- **One writer.** Rails owns the schema and all writes. Phoenix reads only, through a read-only
  database role.

## 3. Product in one paragraph

A small property-operations app for a fictional landlord with 3 properties and ~150 units.
Staff manage properties, units, residents and leases in a **Rails admin**, and run a rent roll
for any date. A **Phoenix LiveView occupancy board** shows every unit's status per property and
updates live, within a second, when a lease changes in Rails. Marketing copy and photos for each
property's public listing are edited in **Sanity Studio** and rendered by a public Rails page.

## 4. Architecture

```
            Sanity Studio (hosted)  ──GROQ──►  Rails: public listing pages
                                                   │
 Staff ──► Rails admin (Hotwire) ──writes──► Postgres ◄──read-only role── Phoenix LiveView board ◄── Staff / viewers
                                                   │                          ▲
                                           NOTIFY lease_changed ──────────────┘ (Postgrex.Notifications → PubSub)
```

| Part | Tech | Responsibility |
|---|---|---|
| `apps/admin` | Rails (current stable), Hotwire, Minitest | Schema + migrations, all writes, admin UI, rent roll, public listing pages, seed data |
| `apps/board` | Elixir + Phoenix LiveView (current stable), ExUnit | Read-only live occupancy board |
| `studio/` | Sanity Studio (TypeScript) | Listing content schema: property headline, description, amenities, photos |
| Database | Postgres (single instance) | Shared; Phoenix connects as `board_reader` with SELECT only |
| Hosting | Render (web services + managed Postgres); Sanity hosted | Free/starter tiers |
| CI | GitHub Actions | Tests + lint + security scan for each app on every push |
| Repo | Monorepo on Ron's **personal** GitHub | Public, with README |

Pin and record the actual versions used in `docs/DECISIONS.md` when setting up (use current
stable releases; do not assume versions from memory).

## 5. Domain model (Rails owns it)

| Table | Key fields |
|---|---|
| `properties` | name, address, city, state, unit_count, sanity_slug |
| `units` | property_id, number, bedrooms (0 = studio), bathrooms, sq_ft, market_rent |
| `residents` | first_name, last_name, email, phone (Faker-generated, clearly fake) |
| `leases` | unit_id, resident_id, start_date, end_date, monthly_rent, status (`pending`, `active`, `notice_given`, `ended`), notice_date, move_out_date |

**Unit status is derived, never stored**, for a given as-of date:

| Status | Rule |
|---|---|
| `occupied` | an `active` lease covers the date and no notice given |
| `on_notice` | occupied, `notice_given`, and no future lease signed |
| `on_notice_rented` | on notice and a `pending` lease starts after move-out |
| `vacant_rented` | no current lease, but a `pending` lease is signed |
| `vacant_available` | no current lease and no pending lease |

Board KPIs per property: **occupancy %** (occupied + on notice), **leased %** (occupied +
vacant_rented + on_notice_rented, minus on_notice), **available units** (vacant_available +
on_notice). Definitions live in one place in Rails (a query object or SQL view) and Phoenix reads
the result. It never re-implements the rules.

Recommended: expose the derived status through a Postgres **view** (`unit_status_today`) created by
a Rails migration, so both apps read one definition. Record the choice in DECISIONS.md.

## 6. Features and acceptance criteria

### Rails admin (`apps/admin`)
1. CRUD for properties, units, residents and leases (Hotwire; no SPA).
   - Lease validations: no overlapping active leases on a unit; end_date after start_date; rent > 0.
2. **Rent roll**: choose a property and as-of date and get one row per unit with status, resident,
   rent and lease dates, plus totals (units, occupied, occupancy %, scheduled rent). CSV export.
3. **Give notice / sign renewal / sign new lease** actions on a lease, each a single clear transaction.
4. Every lease write emits `NOTIFY lease_changed, '<property_id>'` (after commit).
5. **Seed task** (`bin/rails db:seed`): 3 properties, ~150 units, a realistic status mix
   (~90% occupied, some on notice, some pre-leased, a few available). Deterministic seed value.
6. Public listing page per property: content from Sanity via GROQ, plus live available-unit count
   from Postgres. Cached for 5 minutes. Page still renders if Sanity is down (fallback copy).

**Done when:** model and request tests cover lease validations, every status rule, KPI math and
the rent roll totals. No N+1 queries on admin index pages or the rent roll (enforced with
`strict_loading` or the Bullet gem in test). RuboCop (rails-omakase) and Brakeman pass in CI.

### Phoenix board (`apps/board`)
1. `/` lists properties with KPIs. `/properties/:id` shows a unit grid colored by status, with a legend.
2. Listens for `lease_changed` via `Postgrex.Notifications`, broadcasts on Phoenix PubSub, and the
   affected property's LiveViews re-query and re-render. **No polling.**
3. Read-only: connects as `board_reader`; any write attempt fails (test proves it).
4. Supervision: the notification listener runs under the app's supervision tree and reconnects
   after a database restart.

**Done when:** ExUnit + LiveView tests cover rendering and a simulated notification updating the
page. `mix format --check-formatted` and Credo pass in CI. A manual demo shows a lease edit in Rails
updating the board in under 1 second.

### Sanity studio (`studio/`)
1. Schema `propertyListing`: slug (matches `properties.sanity_slug`), headline, description
   (portable text), amenities (array of strings), photos (images with alt text).
2. Three listings seeded, one per property, with placeholder copy and royalty-free or generated
   images.

**Done when:** the public Rails page renders each listing. Content edits show up after cache
expiry. Stretch: a Sanity webhook busts the cache.

### Deploy
- Render: `admin` web service, `board` web service, one managed Postgres. Secrets in Render
  environment variables only.
- README gets the live URLs, an architecture sketch, how to run locally, and links to
  DECISIONS.md and REVIEW-LOG.md.

## 7. Weekend plan

| Block | Goal | Exit check |
|---|---|---|
| Sat AM | Dev environment, monorepo skeleton, CI green on empty apps, DB roles | CI badge green |
| Sat midday | Rails schema, status view, seed, model tests | Seed loads; status tests pass |
| Sat PM | Rails admin CRUD, lease actions, rent roll + CSV, NOTIFY on commit | Rent roll correct on seed data |
| Sun AM | Phoenix board: KPIs, unit grid, notification listener, PubSub, tests | Live update under 1 s locally |
| Sun midday | Sanity schema + content, public listing page with fallback | Listing renders; Sanity-down test passes |
| Sun PM | Render deploy, README, final review pass, fill in REVIEW-LOG | Live URLs work end to end |

**Cut line if time runs short** (cut from the bottom): Sanity webhook → CSV export → public listing
page → renewal action. Never cut: tests, CI, the live board, the review log.

## 8. Out of scope
Authentication beyond HTTP basic auth on admin, payments, maintenance requests, multi-tenancy,
mobile, Databricks (separate project).

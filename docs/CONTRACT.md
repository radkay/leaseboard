# Rails ↔ Phoenix read contract

This file fixes the read interface between Rails (the only writer) and the Phoenix
board (read-only, connects as its environment's reader role — see the Environments
table below). It operationalizes D-003 (status as a
Rails-owned Postgres view) and D-005 (parallel agents split by app, with this contract
as the boundary). It is derived from **SPEC §5**.

**Scope.** Rails owns and creates everything here (views, the NOTIFY). Phoenix only
`SELECT`s the views and `LISTEN`s on the channel; it never re-implements the status or
KPI rules (SPEC §5). Once this file is merged, **changing it is a stop-and-ask item** —
both apps are built against it.

**No resident PII in board-read views.** None of the views below expose resident names,
emails or phone numbers. The board shows status, rents and counts, not who lives where.

Status derivation is **as of a date**; the relations below are the "today" slice
(as-of = `CURRENT_DATE`), which is what the live board renders. The admin rent roll
runs the same rules for an arbitrary date; that is a Rails concern and not part of this
read contract.

---

## Environments

Databases, owner roles and reader roles are defined **only** here. No app config, script
or migration may create, rename or connect to a database or role that is not in this table.

| Environment | Database | Owner (Rails) | Reader (Phoenix) | Created by |
|---|---|---|---|---|
| Development | `leaseboard_dev` | `admin_dev` | `reader_dev` | bootstrap script, as `postgres` |
| Test (local and CI) | `leaseboard_test` | `admin_test` | `reader_test` | bootstrap script, as `postgres` |
| Production | `leaseboard_prod` | `admin_prod` | `reader_prod` | Render creates the database and `admin_prod`; Ron creates `reader_prod` with SQL at deploy |

- No role can connect to another environment's database.
- No app connects as `postgres`; it is used only to create databases and roles.
- Grants and the function lockdown come from one privileges script, never from migrations.

---

## 1. Status values

Exactly these five values, derived per unit and never stored (SPEC §5). Rules, verbatim
from SPEC §5, in terms of the unit's leases (lease statuses are `pending`, `active`,
`notice_given`, `ended`):

| `status` | Rule (SPEC §5) |
|---|---|
| `occupied` | an `active` lease covers the date and no notice given |
| `on_notice` | occupied, `notice_given`, and no future lease signed |
| `on_notice_rented` | on notice and a `pending` lease starts after move-out |
| `vacant_rented` | no current lease, but a `pending` lease is signed |
| `vacant_available` | no current lease and no pending lease |

The five are mutually exclusive and exhaustive: every unit maps to exactly one.

---

## 2. View `unit_status_today`

One row per unit, giving its status today. This is the source for the board's unit grid
(SPEC §6, board feature 1).

| Column | Type | Notes |
|---|---|---|
| `unit_id` | `bigint` | Unit primary key. Unique per row (grain = one row per unit). |
| `property_id` | `bigint` | Owning property. Grouping key and PubSub topic key (`property:<id>`). |
| `unit_number` | `text` | The unit's display label (`units.number`). |
| `bedrooms` | `integer` | Unit's bedroom count; `0` = studio (SPEC §5). |
| `market_rent` | `numeric` | Unit's advertised market rent (`units.market_rent`). |
| `status` | `text` | One of the five values in §1. |
| `current_monthly_rent` | `numeric` | Rent of the current (`active` or `notice_given`) lease; `null` when the unit is vacant. |
| `current_lease_end_date` | `date` | End date of the current lease; `null` when vacant. |
| `notice_date` | `date` | The current lease's notice date; `null` unless it is on notice. |
| `move_out_date` | `date` | The current lease's move-out date; `null` unless set. |
| `next_lease_start_date` | `date` | Start date of the signed future (`pending`) lease; `null` when no future lease is signed. |
| `as_of` | `date` | The as-of date for the derivation; `CURRENT_DATE` for this view. |

The "current lease" is the single live `active`/`notice_given` lease covering `as_of`; the
EXCLUDE constraint guarantees at most one. "Next lease" is the signed `pending` lease that
starts after the current lease ends (the `on_notice_rented` / `vacant_rented` case). Phoenix
maps this read-only (no changesets). Ordering for display is the reader's choice.

---

## 3. View `property_kpis_today`

One row per property with the board KPIs and the per-status counts behind them, so the
board renders KPIs without re-deriving anything (SPEC §5: definitions live in one place in
Rails). Grain = one row per property.

| Column | Type | Notes |
|---|---|---|
| `property_id` | `bigint` | Property primary key. Unique per row. |
| `total_units` | `integer` | Count of the property's units. |
| `occupied` | `integer` | Count of units with status `occupied`. |
| `on_notice` | `integer` | Count of units with status `on_notice`. |
| `on_notice_rented` | `integer` | Count of units with status `on_notice_rented`. |
| `vacant_rented` | `integer` | Count of units with status `vacant_rented`. |
| `vacant_available` | `integer` | Count of units with status `vacant_available`. |
| `occupancy_pct` | `numeric` | Occupancy %, see §3.1. |
| `leased_pct` | `numeric` | Leased %, see §3.1. |
| `available_units` | `integer` | Available units, see §3.1. |

The five per-status counts sum to `total_units`. Percentages are fractions of
`total_units`, `0`–`100`; a property with zero units reports `0`.

### 3.1 KPI definitions (SPEC §5)

SPEC §5 states the KPIs as:

> Board KPIs per property: **occupancy %** (occupied + on notice), **leased %** (occupied
> + vacant_rented + on_notice_rented, minus on_notice), **available units**
> (vacant_available + on_notice).

Rails implements the arithmetic; Phoenix reads the three result columns. SPEC §5's wording
left two points open — whether "on notice" includes `on_notice_rented`, and leased %'s
"minus on_notice" — which Ron resolved (D-010). The definitions are now authoritative:

- **Occupancy %** counts every physically occupied unit: `occupied`, `on_notice`,
  `on_notice_rented`.
- **Leased %** counts units with a current or signed future lease: `occupied`,
  `on_notice_rented`, `vacant_rented`. Units on notice with no new lease (`on_notice`)
  do not count.
- **Available units** = `vacant_available` + `on_notice`.

```
occupancy_pct   = 100 * (occupied + on_notice + on_notice_rented) / total_units
leased_pct      = 100 * (occupied + on_notice_rented + vacant_rented) / total_units
available_units = vacant_available + on_notice
```

---

## 4. View `property_unit_type_kpis_today`

The same KPIs as §3, broken out by unit type so the board can show occupancy within a
bedroom count (SPEC §5). Grain = one row per (`property_id`, `bedrooms`).

| Column | Type | Notes |
|---|---|---|
| `property_id` | `bigint` | Property. |
| `bedrooms` | `integer` | Bedroom count for this bucket; `0` = studio. |
| `total_units` | `integer` | Units of this type in the property. |
| `occupied` | `integer` | Count with status `occupied`. |
| `on_notice` | `integer` | Count with status `on_notice`. |
| `on_notice_rented` | `integer` | Count with status `on_notice_rented`. |
| `vacant_rented` | `integer` | Count with status `vacant_rented`. |
| `vacant_available` | `integer` | Count with status `vacant_available`. |
| `occupancy_pct` | `numeric` | Occupancy % over this bucket (§3.1 / D-010). |
| `leased_pct` | `numeric` | Leased % over this bucket (§3.1 / D-010). |
| `available_units` | `integer` | Available units over this bucket (§3.1 / D-010). |

`(property_id, bedrooms)` is unique. A bucket exists only for bedroom counts the property
actually has. The per-status counts sum to `total_units`; percentages are `0`–`100` over the
bucket's `total_units`, using the exact same definitions as §3.1 (D-010), applied within the
unit type.

---

## 5. View `lease_expirations_12m`

A dense 12-month expirations series per property — the current month and the next 11 —
counting the current lease on each unit whose term ends in that month. Grain = one row per
(`property_id`, `month`).

| Column | Type | Notes |
|---|---|---|
| `property_id` | `bigint` | Property. |
| `month` | `date` | First day of the month (e.g. `2026-11-01`). 12 rows per property: `date_trunc('month', CURRENT_DATE)` through `+11` months. |
| `expiring_total` | `integer` | Current (`active` or `notice_given`) leases on the property's units whose `end_date` falls in `month`. |
| `expiring_renewed_or_relet` | `integer` | Of those, the ones whose unit has a signed lease (`pending`) that starts after the expiring lease ends. |
| `expiring_open` | `integer` | Of those, the ones with no such follow-on lease. |

`expiring_total = expiring_renewed_or_relet + expiring_open`. Every (`property_id`, `month`)
in the window appears, with zeros when nothing expires that month. "Expiring" counts the
current lease's own `end_date`; `ended` and `pending` leases are not themselves counted as
expiring.

---

## 6. NOTIFY channel `lease_changed`

Rails emits, after commit, on every lease write (create / give notice / sign renewal /
sign new lease — SPEC §6 admin features 3–4):

- **Channel:** `lease_changed`
- **Payload:** the affected unit's **property id**, as text (Postgres `NOTIFY` payloads
  are always text; the reader casts to integer).

Phoenix listens via `Postgrex.Notifications` under its supervision tree, broadcasts on the
Phoenix PubSub topic `property:<property_id>`, and the affected property's LiveViews
re-query the views (§2–§5) and re-render. No polling (SPEC §6, board features 2 and 4).

Contract guarantee: **one notification per committed lease change, carrying the property
id whose board slice may have changed.** Rails may coalesce multiple changes to the same
property within one transaction into a single notification.

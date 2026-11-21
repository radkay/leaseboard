# Rails ↔ Phoenix read contract

This file fixes the read interface between Rails (the only writer) and the Phoenix
board (read-only, connects as `board_reader`). It operationalizes D-003 (status as a
Rails-owned Postgres view) and D-005 (parallel agents split by app, with this contract
as the boundary). It is derived from **SPEC §5**.

**Scope.** Rails owns and creates everything here (views, the NOTIFY). Phoenix only
`SELECT`s the views and `LISTEN`s on the channel; it never re-implements the status or
KPI rules (SPEC §5). Once this file is merged, **changing it is a stop-and-ask item** —
both apps are built against it.

Status derivation is **as of a date**; the relations below are the "today" slice
(as-of = `CURRENT_DATE`), which is what the live board renders. The admin rent roll
runs the same rules for an arbitrary date; that is a Rails concern and not part of this
read contract.

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
| `status` | `text` | One of the five values in §1. |
| `as_of` | `date` | The as-of date for the derivation; `CURRENT_DATE` for this view. |

Phoenix maps this read-only (no changesets). Ordering for display is the reader's choice.

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

Rails implements the arithmetic; Phoenix reads the three result columns. **Two points in
§5's wording are ambiguous and must be confirmed before the KPI columns are relied on**
(the status rules in §1, the view columns, and the NOTIFY below are unaffected):

1. **Does "on notice" mean just `on_notice`, or `on_notice` + `on_notice_rented`?** Both
   statuses are physically occupied now, so occupancy % reads most naturally as
   `(occupied + on_notice + on_notice_rented) / total`. But "available units
   (vacant_available + on_notice)" should almost certainly *exclude* `on_notice_rented`
   (those units already have a replacement lease), i.e. `vacant_available + on_notice`.
   So "on notice" appears to mean different sets in different KPIs.
2. **Leased %'s "minus on_notice".** `occupied`, `on_notice` and `on_notice_rented` are
   distinct statuses, so "occupied + … minus on_notice" only makes sense if "occupied"
   there means *all physically-occupied* units (`occupied + on_notice + on_notice_rented`)
   before subtracting `on_notice`.

Proposed reading, to confirm with Ron (not yet authoritative):

```
occupancy_pct   = 100 * (occupied + on_notice + on_notice_rented) / total_units
leased_pct      = 100 * (occupied + on_notice_rented + vacant_rented) / total_units
available_units = vacant_available + on_notice
```

Until Ron confirms, treat the **column names and types** as fixed and the **formulas**
as provisional.

---

## 4. NOTIFY channel `lease_changed`

Rails emits, after commit, on every lease write (create / give notice / sign renewal /
sign new lease — SPEC §6 admin features 3–4):

- **Channel:** `lease_changed`
- **Payload:** the affected unit's **property id**, as text (Postgres `NOTIFY` payloads
  are always text; the reader casts to integer).

Phoenix listens via `Postgrex.Notifications` under its supervision tree, broadcasts on the
Phoenix PubSub topic `property:<property_id>`, and the affected property's LiveViews
re-query §2/§3 and re-render. No polling (SPEC §6, board features 2 and 4).

Contract guarantee: **one notification per committed lease change, carrying the property
id whose board slice may have changed.** Rails may coalesce multiple changes to the same
property within one transaction into a single notification.

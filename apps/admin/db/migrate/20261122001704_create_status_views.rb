class CreateStatusViews < ActiveRecord::Migration[8.1]
  # The four board-read views from CONTRACT.md. Rails owns them; Phoenix reads them.
  # Status rules are §1; KPI definitions are §3.1 / D-010.
  def up
    execute <<~SQL
      CREATE VIEW unit_status_today AS
      WITH current_lease AS (
        -- The one live lease (active or notice_given) covering today. The EXCLUDE
        -- constraint guarantees at most one; DISTINCT ON is belt-and-suspenders.
        SELECT DISTINCT ON (l.unit_id)
          l.unit_id, l.status, l.monthly_rent, l.end_date, l.notice_date, l.move_out_date
        FROM leases l
        WHERE l.status IN ('active', 'notice_given')
          AND CURRENT_DATE BETWEEN l.start_date AND l.end_date
        ORDER BY l.unit_id, l.start_date DESC
      ),
      next_pending AS (
        -- The soonest signed future lease on the unit, if any.
        SELECT DISTINCT ON (l.unit_id) l.unit_id, l.start_date
        FROM leases l
        WHERE l.status = 'pending'
        ORDER BY l.unit_id, l.start_date ASC
      )
      SELECT
        u.id           AS unit_id,
        u.property_id  AS property_id,
        u.number       AS unit_number,
        u.bedrooms     AS bedrooms,
        u.market_rent  AS market_rent,
        CASE
          WHEN cl.status = 'active' THEN 'occupied'
          WHEN cl.status = 'notice_given' AND np.unit_id IS NOT NULL THEN 'on_notice_rented'
          WHEN cl.status = 'notice_given' THEN 'on_notice'
          WHEN cl.unit_id IS NULL AND np.unit_id IS NOT NULL THEN 'vacant_rented'
          ELSE 'vacant_available'
        END            AS status,
        cl.monthly_rent AS current_monthly_rent,
        cl.end_date     AS current_lease_end_date,
        cl.notice_date  AS notice_date,
        cl.move_out_date AS move_out_date,
        np.start_date   AS next_lease_start_date,
        CURRENT_DATE    AS as_of
      FROM units u
      LEFT JOIN current_lease cl ON cl.unit_id = u.id
      LEFT JOIN next_pending  np ON np.unit_id = u.id;
    SQL

    execute <<~SQL
      CREATE VIEW property_kpis_today AS
      SELECT
        p.id AS property_id,
        COUNT(ust.unit_id) AS total_units,
        COUNT(*) FILTER (WHERE ust.status = 'occupied')         AS occupied,
        COUNT(*) FILTER (WHERE ust.status = 'on_notice')        AS on_notice,
        COUNT(*) FILTER (WHERE ust.status = 'on_notice_rented') AS on_notice_rented,
        COUNT(*) FILTER (WHERE ust.status = 'vacant_rented')    AS vacant_rented,
        COUNT(*) FILTER (WHERE ust.status = 'vacant_available') AS vacant_available,
        CASE WHEN COUNT(ust.unit_id) = 0 THEN 0 ELSE
          ROUND(100.0 * COUNT(*) FILTER (WHERE ust.status IN ('occupied', 'on_notice', 'on_notice_rented'))
                / COUNT(ust.unit_id), 2)
        END AS occupancy_pct,
        CASE WHEN COUNT(ust.unit_id) = 0 THEN 0 ELSE
          ROUND(100.0 * COUNT(*) FILTER (WHERE ust.status IN ('occupied', 'on_notice_rented', 'vacant_rented'))
                / COUNT(ust.unit_id), 2)
        END AS leased_pct,
        COUNT(*) FILTER (WHERE ust.status IN ('vacant_available', 'on_notice')) AS available_units
      FROM properties p
      LEFT JOIN unit_status_today ust ON ust.property_id = p.id
      GROUP BY p.id;
    SQL

    execute <<~SQL
      CREATE VIEW property_unit_type_kpis_today AS
      SELECT
        ust.property_id AS property_id,
        ust.bedrooms    AS bedrooms,
        COUNT(ust.unit_id) AS total_units,
        COUNT(*) FILTER (WHERE ust.status = 'occupied')         AS occupied,
        COUNT(*) FILTER (WHERE ust.status = 'on_notice')        AS on_notice,
        COUNT(*) FILTER (WHERE ust.status = 'on_notice_rented') AS on_notice_rented,
        COUNT(*) FILTER (WHERE ust.status = 'vacant_rented')    AS vacant_rented,
        COUNT(*) FILTER (WHERE ust.status = 'vacant_available') AS vacant_available,
        CASE WHEN COUNT(ust.unit_id) = 0 THEN 0 ELSE
          ROUND(100.0 * COUNT(*) FILTER (WHERE ust.status IN ('occupied', 'on_notice', 'on_notice_rented'))
                / COUNT(ust.unit_id), 2)
        END AS occupancy_pct,
        CASE WHEN COUNT(ust.unit_id) = 0 THEN 0 ELSE
          ROUND(100.0 * COUNT(*) FILTER (WHERE ust.status IN ('occupied', 'on_notice_rented', 'vacant_rented'))
                / COUNT(ust.unit_id), 2)
        END AS leased_pct,
        COUNT(*) FILTER (WHERE ust.status IN ('vacant_available', 'on_notice')) AS available_units
      FROM unit_status_today ust
      GROUP BY ust.property_id, ust.bedrooms;
    SQL

    execute <<~SQL
      CREATE VIEW lease_expirations_12m AS
      WITH months AS (
        SELECT (date_trunc('month', CURRENT_DATE)::date + (n || ' months')::interval)::date AS month
        FROM generate_series(0, 11) AS n
      ),
      expiring AS (
        SELECT
          u.property_id,
          date_trunc('month', l.end_date)::date AS month,
          EXISTS (
            SELECT 1 FROM leases nl
            WHERE nl.unit_id = l.unit_id
              AND nl.status = 'pending'
              AND nl.start_date > l.end_date
          ) AS has_followon
        FROM leases l
        JOIN units u ON u.id = l.unit_id
        WHERE l.status IN ('active', 'notice_given')
      )
      SELECT
        p.id AS property_id,
        m.month AS month,
        COUNT(e.has_followon) AS expiring_total,
        COUNT(*) FILTER (WHERE e.has_followon) AS expiring_renewed_or_relet,
        COUNT(*) FILTER (WHERE e.has_followon IS FALSE) AS expiring_open
      FROM properties p
      CROSS JOIN months m
      LEFT JOIN expiring e ON e.property_id = p.id AND e.month = m.month
      GROUP BY p.id, m.month;
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS lease_expirations_12m"
    execute "DROP VIEW IF EXISTS property_unit_type_kpis_today"
    execute "DROP VIEW IF EXISTS property_kpis_today"
    execute "DROP VIEW IF EXISTS unit_status_today"
  end
end

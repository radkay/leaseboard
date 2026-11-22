class RefactorStatusIntoFunction < ActiveRecord::Migration[8.1]
  # Extract the per-unit status derivation into unit_status_as_of(date) so the board
  # view (today) and the admin rent roll (any date) share one definition of the rules
  # (CLAUDE.md: status rules live in one place). unit_status_today becomes a thin wrapper
  # over the function at CURRENT_DATE; the KPI views are unchanged apart from being
  # rebuilt on top of it. The function also exposes current_resident_id for the admin
  # rent roll; the board view deliberately omits it (no resident data in board views).
  def up
    execute <<~SQL
      CREATE FUNCTION unit_status_as_of(as_of date)
      RETURNS TABLE (
        unit_id bigint,
        property_id bigint,
        unit_number character varying,
        bedrooms integer,
        market_rent numeric,
        status text,
        current_resident_id bigint,
        current_monthly_rent numeric,
        current_lease_end_date date,
        notice_date date,
        move_out_date date,
        next_lease_start_date date,
        as_of date
      )
      LANGUAGE sql STABLE
      -- SECURITY DEFINER so the function reads the base tables with its owner's rights,
      -- the same way a view does. This lets board_reader read the views (which call it)
      -- without any grant on units/leases. search_path is pinned for safety.
      SECURITY DEFINER SET search_path = pg_catalog, public
      AS $func$
        WITH current_lease AS (
          SELECT DISTINCT ON (l.unit_id)
            l.unit_id, l.status, l.resident_id, l.monthly_rent, l.end_date, l.notice_date, l.move_out_date
          FROM leases l
          WHERE l.status IN ('active', 'notice_given')
            AND as_of BETWEEN l.start_date AND l.end_date
          ORDER BY l.unit_id, l.start_date DESC
        ),
        next_pending AS (
          SELECT DISTINCT ON (l.unit_id) l.unit_id, l.start_date
          FROM leases l
          WHERE l.status = 'pending'
          ORDER BY l.unit_id, l.start_date ASC
        )
        SELECT
          u.id, u.property_id, u.number, u.bedrooms, u.market_rent,
          CASE
            WHEN cl.status = 'active' THEN 'occupied'
            WHEN cl.status = 'notice_given' AND np.unit_id IS NOT NULL THEN 'on_notice_rented'
            WHEN cl.status = 'notice_given' THEN 'on_notice'
            WHEN cl.unit_id IS NULL AND np.unit_id IS NOT NULL THEN 'vacant_rented'
            ELSE 'vacant_available'
          END,
          cl.resident_id, cl.monthly_rent, cl.end_date, cl.notice_date, cl.move_out_date,
          np.start_date, as_of
        FROM units u
        LEFT JOIN current_lease cl ON cl.unit_id = u.id
        LEFT JOIN next_pending  np ON np.unit_id = u.id
      $func$;
    SQL

    execute "DROP VIEW property_unit_type_kpis_today"
    execute "DROP VIEW property_kpis_today"
    execute "DROP VIEW unit_status_today"

    # Rebuilt on the function; omits current_resident_id (no resident data on the board).
    execute <<~SQL
      CREATE VIEW unit_status_today AS
      SELECT unit_id, property_id, unit_number, bedrooms, market_rent, status,
             current_monthly_rent, current_lease_end_date, notice_date, move_out_date,
             next_lease_start_date, as_of
      FROM unit_status_as_of(CURRENT_DATE);
    SQL

    create_kpi_views
  end

  def down
    execute "DROP VIEW property_unit_type_kpis_today"
    execute "DROP VIEW property_kpis_today"
    execute "DROP VIEW unit_status_today"
    execute "DROP FUNCTION unit_status_as_of(date)"

    execute <<~SQL
      CREATE VIEW unit_status_today AS
      WITH current_lease AS (
        SELECT DISTINCT ON (l.unit_id)
          l.unit_id, l.status, l.monthly_rent, l.end_date, l.notice_date, l.move_out_date
        FROM leases l
        WHERE l.status IN ('active', 'notice_given')
          AND CURRENT_DATE BETWEEN l.start_date AND l.end_date
        ORDER BY l.unit_id, l.start_date DESC
      ),
      next_pending AS (
        SELECT DISTINCT ON (l.unit_id) l.unit_id, l.start_date
        FROM leases l
        WHERE l.status = 'pending'
        ORDER BY l.unit_id, l.start_date ASC
      )
      SELECT
        u.id AS unit_id, u.property_id AS property_id, u.number AS unit_number,
        u.bedrooms AS bedrooms, u.market_rent AS market_rent,
        CASE
          WHEN cl.status = 'active' THEN 'occupied'
          WHEN cl.status = 'notice_given' AND np.unit_id IS NOT NULL THEN 'on_notice_rented'
          WHEN cl.status = 'notice_given' THEN 'on_notice'
          WHEN cl.unit_id IS NULL AND np.unit_id IS NOT NULL THEN 'vacant_rented'
          ELSE 'vacant_available'
        END AS status,
        cl.monthly_rent AS current_monthly_rent, cl.end_date AS current_lease_end_date,
        cl.notice_date AS notice_date, cl.move_out_date AS move_out_date,
        np.start_date AS next_lease_start_date, CURRENT_DATE AS as_of
      FROM units u
      LEFT JOIN current_lease cl ON cl.unit_id = u.id
      LEFT JOIN next_pending  np ON np.unit_id = u.id;
    SQL

    create_kpi_views
  end

  private

  def create_kpi_views
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
  end
end

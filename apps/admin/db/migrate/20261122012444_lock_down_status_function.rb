class LockDownStatusFunction < ActiveRecord::Migration[8.1]
  # unit_status_as_of is SECURITY DEFINER, so leaving EXECUTE to PUBLIC lets any role call
  # it directly with the owner's rights (R-012). Postgres checks a function's EXECUTE against
  # the invoking role even through a view, so board_reader *must* keep EXECUTE to read the
  # views (R-015). We therefore REVOKE from PUBLIC and GRANT only to board_reader, and make a
  # direct call harmless: the function exposes the current lease's **id** (not the resident's),
  # so it returns no personal data. The rent roll joins that lease id to residents itself.
  #
  # Recreating the function changes its return type, so the dependent views are rebuilt too;
  # that also re-grants board_reader's SELECT on them, which task 8 had dropped (R-014).
  def up
    drop_status_objects
    create_function(id_column: "current_lease_id bigint", id_select: "cl.id")
    execute "REVOKE EXECUTE ON FUNCTION unit_status_as_of(date) FROM PUBLIC"
    grant_execute_to_board_reader
    create_status_views
    BoardReaderRole.grant_reads!(connection)
  end

  def down
    drop_status_objects
    create_function(id_column: "current_resident_id bigint", id_select: "cl.resident_id")
    execute "GRANT EXECUTE ON FUNCTION unit_status_as_of(date) TO PUBLIC"
    create_status_views
    BoardReaderRole.grant_reads!(connection)
  end

  private

  def drop_status_objects
    execute "DROP VIEW property_unit_type_kpis_today"
    execute "DROP VIEW property_kpis_today"
    execute "DROP VIEW unit_status_today"
    execute "DROP FUNCTION unit_status_as_of(date)"
  end

  def grant_execute_to_board_reader
    return unless connection.select_value("SELECT 1 FROM pg_roles WHERE rolname = 'board_reader'")

    execute "GRANT EXECUTE ON FUNCTION unit_status_as_of(date) TO board_reader"
  end

  def create_function(id_column:, id_select:)
    execute <<~SQL
      CREATE FUNCTION unit_status_as_of(as_of date)
      RETURNS TABLE (
        unit_id bigint,
        property_id bigint,
        unit_number character varying,
        bedrooms integer,
        market_rent numeric,
        status text,
        #{id_column},
        current_monthly_rent numeric,
        current_lease_end_date date,
        notice_date date,
        move_out_date date,
        next_lease_start_date date,
        as_of date
      )
      LANGUAGE sql STABLE
      SECURITY DEFINER SET search_path = pg_catalog, public
      AS $func$
        WITH current_lease AS (
          SELECT DISTINCT ON (l.unit_id)
            l.unit_id, l.id, l.resident_id, l.status, l.monthly_rent, l.end_date, l.notice_date, l.move_out_date
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
          #{id_select},
          cl.monthly_rent, cl.end_date, cl.notice_date, cl.move_out_date,
          np.start_date, as_of
        FROM units u
        LEFT JOIN current_lease cl ON cl.unit_id = u.id
        LEFT JOIN next_pending  np ON np.unit_id = u.id
      $func$;
    SQL
  end

  def create_status_views
    execute <<~SQL
      CREATE VIEW unit_status_today AS
      SELECT unit_id, property_id, unit_number, bedrooms, market_rent, status,
             current_monthly_rent, current_lease_end_date, notice_date, move_out_date,
             next_lease_start_date, as_of
      FROM unit_status_as_of(CURRENT_DATE);
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
  end
end

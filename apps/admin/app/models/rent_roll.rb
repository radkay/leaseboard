# The admin rent roll for a property as of a date. One SQL query over the shared
# unit_status_as_of(date) function (so the status rules match the board), joined to
# residents for names — admin-only, which is why this reads the function's
# current_resident_id rather than a board view. Totals are computed from the loaded
# rows, so the whole report is a single query (no N+1).
class RentRoll
  Row = Data.define(:unit_number, :bedrooms, :status, :resident_name,
                    :monthly_rent, :market_rent, :lease_end_date)

  OCCUPIED_STATUSES = %w[occupied on_notice on_notice_rented].freeze

  attr_reader :property, :as_of

  def initialize(property, as_of: Date.current)
    @property = property
    @as_of = as_of
  end

  def rows
    @rows ||= fetch.map do |r|
      Row.new(
        unit_number: r["unit_number"], bedrooms: r["bedrooms"], status: r["status"],
        resident_name: r["resident_name"], monthly_rent: r["current_monthly_rent"],
        market_rent: r["market_rent"], lease_end_date: r["current_lease_end_date"]
      )
    end
  end

  def total_units
    rows.size
  end

  def occupied_units
    rows.count { |r| OCCUPIED_STATUSES.include?(r.status) }
  end

  def occupancy_pct
    return 0 if total_units.zero?

    (100.0 * occupied_units / total_units).round(2)
  end

  # Rent currently scheduled to be collected: the sum of the live leases' monthly rent.
  def scheduled_rent
    rows.sum { |r| r.monthly_rent || 0 }
  end

  # Minimal RFC 4180 CSV. The `csv` library is no longer a default gem in Ruby 4.0, and
  # adding a dependency is a stop-and-ask item, so this writes the few fields directly.
  def to_csv
    lines = [ csv_line([ "Unit", "Bedrooms", "Status", "Resident", "Monthly rent", "Market rent", "Lease end" ]) ]
    rows.each do |r|
      lines << csv_line([ r.unit_number, r.bedrooms, r.status, r.resident_name, r.monthly_rent, r.market_rent, r.lease_end_date ])
    end
    lines << ""
    lines << csv_line([ "Units", total_units, "Occupied", occupied_units, "Occupancy %", occupancy_pct,
                       "Scheduled rent", scheduled_rent ])
    "#{lines.join("\n")}\n"
  end

  private

  def csv_line(fields)
    fields.map { |field| csv_field(field) }.join(",")
  end

  def csv_field(value)
    string = value.to_s
    string.match?(/["\n\r,]/) ? %("#{string.gsub('"', '""')}") : string
  end

  def fetch
    # The status function returns the current lease id (not resident data); the rent roll,
    # as an admin query, joins that to residents itself for the name column.
    sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL, as_of, property.id ])
      SELECT s.unit_number, s.bedrooms, s.status, s.market_rent,
             s.current_monthly_rent, s.current_lease_end_date,
             CASE WHEN r.id IS NULL THEN NULL ELSE r.first_name || ' ' || r.last_name END AS resident_name
      FROM unit_status_as_of(?) s
      LEFT JOIN leases cl ON cl.id = s.current_lease_id
      LEFT JOIN residents r ON r.id = cl.resident_id
      WHERE s.property_id = ?
      ORDER BY s.unit_number
    SQL
    ActiveRecord::Base.connection.select_all(sql)
  end
end

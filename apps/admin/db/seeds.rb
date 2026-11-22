require "faker"

# Deterministic demo data: 3 properties, ~150 units, ~90% occupied, with a realistic
# mix of on-notice, pre-leased and available units. Residents are clearly synthetic
# (Faker names, example.com emails, 555 phones). Re-running reproduces the same data.
SEED = 20_261_122
Faker::Config.random = Random.new(SEED)
rng = Random.new(SEED)

PROPERTIES = [
  { name: "Maple Court", unit_count: 60 },
  { name: "Riverside Lofts", unit_count: 50 },
  { name: "Oakwood Flats", unit_count: 40 }
].freeze

# Weighted toward 1–2 bedrooms, with some studios (0) and a few 3-bedrooms.
BEDROOM_WEIGHTS = [ 0, 1, 1, 1, 2, 2, 2, 3 ].freeze

today = Date.current
total_units = PROPERTIES.sum { |p| p[:unit_count] }

# A fixed status plan so the occupancy mix is exact, not just probabilistic.
status_counts = {
  "occupied"         => (total_units * 0.80).round,
  "on_notice"        => (total_units * 0.06).round,
  "on_notice_rented" => (total_units * 0.04).round,
  "vacant_rented"    => (total_units * 0.04).round
}
status_counts["vacant_available"] = total_units - status_counts.values.sum
status_plan = status_counts.flat_map { |status, n| [ status ] * n }.shuffle(random: rng)

puts "Clearing existing data…"
Lease.delete_all
Unit.delete_all
Resident.delete_all
Property.delete_all

resident_seq = 0
make_resident = lambda do
  resident_seq += 1
  first = Faker::Name.first_name
  last = Faker::Name.last_name
  Resident.create!(
    first_name: first,
    last_name: last,
    email: "#{first.downcase}.#{last.downcase}.#{resident_seq}@example.com",
    phone: format("(555) %03d-%04d", rng.rand(100..999), rng.rand(0..9999))
  )
end

create_lease_set = lambda do |unit, status, rent|
  case status
  when "occupied"
    start = today - rng.rand(30..330)
    unit.leases.create!(resident: make_resident.call, start_date: start, end_date: start + 365,
                        monthly_rent: rent, status: :active)
  when "on_notice"
    start = today - rng.rand(300..340)
    ends = today + rng.rand(15..75)
    unit.leases.create!(resident: make_resident.call, start_date: start, end_date: ends,
                        monthly_rent: rent, status: :notice_given,
                        notice_date: today - rng.rand(5..25), move_out_date: ends)
  when "on_notice_rented"
    start = today - rng.rand(300..340)
    ends = today + rng.rand(15..60)
    unit.leases.create!(resident: make_resident.call, start_date: start, end_date: ends,
                        monthly_rent: rent, status: :notice_given,
                        notice_date: today - rng.rand(5..25), move_out_date: ends)
    next_start = ends + rng.rand(1..20)
    unit.leases.create!(resident: make_resident.call, start_date: next_start, end_date: next_start + 365,
                        monthly_rent: rent + rng.rand(0..100), status: :pending)
  when "vacant_rented"
    next_start = today + rng.rand(10..60)
    unit.leases.create!(resident: make_resident.call, start_date: next_start, end_date: next_start + 365,
                        monthly_rent: rent, status: :pending)
  when "vacant_available"
    # No lease.
  end
end

unit_index = 0
PROPERTIES.each do |spec|
  property = Property.create!(
    name: spec[:name],
    address: Faker::Address.street_address,
    city: Faker::Address.city,
    state: Faker::Address.state_abbr,
    sanity_slug: spec[:name].downcase.gsub(/[^a-z0-9]+/, "-")
  )

  spec[:unit_count].times do |i|
    floor = (i / 10) + 1
    bedrooms = BEDROOM_WEIGHTS.sample(random: rng)
    rent = 900 + (bedrooms * 450) + rng.rand(0..200)
    unit = property.units.create!(
      number: format("%d%02d", floor, (i % 10) + 1),
      bedrooms: bedrooms,
      bathrooms: bedrooms <= 1 ? 1.0 : (bedrooms == 2 ? 2.0 : 2.5),
      sq_ft: 450 + (bedrooms * 250) + rng.rand(0..150),
      market_rent: rent
    )

    create_lease_set.call(unit, status_plan[unit_index], rent)
    unit_index += 1
  end
end

occupied_like = Lease.connection.select_value(
  "SELECT count(*) FROM unit_status_today WHERE status IN ('occupied', 'on_notice', 'on_notice_rented')"
)
puts "Seeded #{Property.count} properties, #{Unit.count} units, #{Resident.count} residents, #{Lease.count} leases."
puts "Occupancy: #{(100.0 * occupied_like / Unit.count).round(1)}% (#{occupied_like}/#{Unit.count})."

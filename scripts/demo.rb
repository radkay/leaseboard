# Drives the Phoenix occupancy board live by changing one lease through Rails's
# real lease actions. Run it with scripts/demo, which runs this file with
# `bin/rails runner` against the admin's development database (leaseboard_dev) —
# the same database the board reads.
#
# Watch a property's board (http://localhost:4000/properties/<id>) while it runs:
# the affected unit flips Occupied → On notice → On notice · re-let, each update
# arriving live over PubSub with no page reload.

pause = Integer(ENV.fetch("DEMO_PAUSE_SECONDS", "6"))

def say(message) = puts("\n\e[1;36m» #{message}\e[0m")

# 1. Pick a currently-occupied unit: an active lease that covers today.
lease =
  Lease.active
       .where("start_date <= :on AND end_date >= :on", on: Date.current)
       .order(:id)
       .first

if lease.nil?
  abort "No occupied unit found. Seed the shared database first (see scripts/README.md)."
end

unit = lease.unit
property = unit.property

puts "Writing to database: #{ActiveRecord::Base.connection_db_config.database}"
say "Property: #{property.name} — Unit #{unit.number}"
puts "  Open the board:  http://localhost:4000/properties/#{property.id}"
puts "  Unit #{unit.number} should be OCCUPIED (green) right now."
sleep pause

# 2. Give notice — the board flips the unit to ON NOTICE (amber) and flashes.
move_out = [Date.current + 30, lease.end_date].min
say "Giving notice on unit #{unit.number} (move-out #{move_out})…"
Leases::GiveNotice.call(lease, move_out_date: move_out)
puts "  Board: unit #{unit.number} → ON NOTICE (amber), with a brief flash."
sleep pause

# 3. Sign a new lease starting after the current term ends — the board shows
#    ON NOTICE · RE-LET (teal). It starts after end_date so it doesn't overlap the
#    still-live lease (Lease#no_overlapping_live_leases), and after move-out so the
#    status derivation counts it as re-let (CONTRACT.md §1).
new_start = lease.end_date + 1
say "Signing a new lease on unit #{unit.number} starting #{new_start}…"
Leases::SignNewLease.call(
  unit: unit,
  resident_attributes: {
    first_name: "Demo",
    last_name: "Tenant",
    email: "demo.tenant+#{Time.now.to_i}@example.com",
    phone: "555-0100"
  },
  start_date: new_start,
  end_date: new_start + 365,
  monthly_rent: unit.market_rent
)
puts "  Board: unit #{unit.number} → ON NOTICE · RE-LET (teal)."
sleep pause

say "Done — the board updated live on each step, no reloads."

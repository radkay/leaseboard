require "test_helper"
require "pg"

class LeaseNotifyTest < ActiveSupport::TestCase
  # after_commit only fires on a real commit, so this test commits its writes rather
  # than relying on the rolled-back per-test transaction.
  self.use_transactional_tests = false

  test "a committed lease write emits NOTIFY lease_changed with the property id" do
    property = Property.create!(name: "Notify Co", address: "1 N St", city: "Austin", state: "TX")
    unit = property.units.create!(number: "1", bedrooms: 1, bathrooms: 1, sq_ft: 500, market_rent: 1000)
    resident = Resident.create!(first_name: "Nora", last_name: "Tify", email: "notify@example.test", phone: "555-0000")

    listener = new_listener
    listener.exec("LISTEN lease_changed")

    # Creating property/unit/resident does not notify (only Lease does), so this write
    # is the one notification we expect.
    unit.leases.create!(resident: resident, start_date: Date.current - 10, end_date: Date.current + 355,
                        monthly_rent: 1000, status: :active)

    received = nil
    listener.wait_for_notify(5) { |_channel, _pid, payload| received = payload }
    assert_equal property.id.to_s, received
  ensure
    listener&.close
    property&.destroy # cascades units and leases
    resident&.destroy
  end

  private

  def new_listener
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    PG.connect(host: cfg[:host] || "localhost", port: cfg[:port] || 5432,
               dbname: cfg[:database], user: cfg[:username], password: cfg[:password])
  end
end

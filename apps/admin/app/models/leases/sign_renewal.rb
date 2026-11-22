module Leases
  # Signs a renewal for the current tenant: a new pending term on the same unit that
  # starts the day after the current lease ends.
  class SignRenewal
    def self.call(lease, new_end_date:, monthly_rent:)
      Lease.transaction do
        lease.unit.leases.create!(
          resident: lease.resident,
          start_date: lease.end_date + 1,
          end_date: new_end_date,
          monthly_rent: monthly_rent,
          status: :pending
        )
      end
    end
  end
end

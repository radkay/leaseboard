module Leases
  # Signs a new lease for a unit, creating the resident and the lease together. A new
  # term starting today is active; a future term is pending. The resident and lease are
  # created in one transaction, so a failure on either leaves nothing behind.
  class SignNewLease
    def self.call(unit:, resident_attributes:, start_date:, end_date:, monthly_rent:, status: nil)
      start_date = start_date.to_date
      status ||= start_date <= Date.current ? :active : :pending

      Lease.transaction do
        resident = Resident.create!(resident_attributes)
        unit.leases.create!(
          resident: resident,
          start_date: start_date,
          end_date: end_date,
          monthly_rent: monthly_rent,
          status: status
        )
      end
    end
  end
end

module Leases
  # Moves an occupied lease to notice_given, recording the notice and move-out dates.
  class GiveNotice
    def self.call(lease, move_out_date:, notice_date: Date.current)
      Lease.transaction do
        lease.update!(status: :notice_given, notice_date: notice_date, move_out_date: move_out_date)
      end
      lease
    end
  end
end

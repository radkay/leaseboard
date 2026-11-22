class Lease < ApplicationRecord
  # A lease is "live" until it ends: pending (signed, future), active (current),
  # or notice_given (current, tenant leaving). Only live leases can occupy a unit.
  LIVE_STATUSES = %w[pending active notice_given].freeze

  belongs_to :unit
  belongs_to :resident

  enum :status, {
    pending: "pending",
    active: "active",
    notice_given: "notice_given",
    ended: "ended"
  }

  validates :start_date, :end_date, :monthly_rent, :status, presence: true
  validates :monthly_rent, numericality: { greater_than: 0 }
  validate :end_date_after_start_date
  validate :no_overlapping_live_leases

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after the start date") if end_date <= start_date
  end

  # Mirrors the leases_no_overlapping_live_leases EXCLUDE constraint, so callers get a
  # validation error instead of a database exception. The DB constraint is the source
  # of truth; this is the friendly check.
  def no_overlapping_live_leases
    return if ended? || unit_id.blank? || start_date.blank? || end_date.blank?

    clash = Lease.where(unit_id: unit_id)
      .where.not(id: id)
      .where(status: LIVE_STATUSES)
      .where(
        "daterange(start_date, end_date, '[]') && daterange(?::date, ?::date, '[]')",
        start_date, end_date
      )
    errors.add(:base, "overlaps another live lease on this unit") if clash.exists?
  end
end

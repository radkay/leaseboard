defmodule Board.Occupancy.LeaseExpiration do
  @moduledoc """
  One property-month of the 12-month lease-expirations series, read from the
  Rails-owned view `lease_expirations_12m` (CONTRACT.md §5). Every month in the
  window appears, with zeros when nothing expires. Grain = (property_id, month).
  Read-only — no changeset.
  """
  use Ecto.Schema

  @primary_key false
  schema "lease_expirations_12m" do
    field :property_id, :integer
    field :month, :date
    field :expiring_total, :integer
    field :expiring_renewed_or_relet, :integer
    field :expiring_open, :integer
  end
end

defmodule Board.Occupancy.UnitStatus do
  @moduledoc """
  One unit's derived status today, read from the Rails-owned view
  `unit_status_today` (CONTRACT.md §2). The status rules live in Rails; the board
  never re-derives them. The view omits the resident id, so the board never sees
  resident identity (no PII). Read-only — no changeset.
  """
  use Ecto.Schema

  @primary_key {:unit_id, :id, autogenerate: false}
  schema "unit_status_today" do
    field :property_id, :integer
    field :unit_number, :string
    field :bedrooms, :integer
    field :market_rent, :decimal
    field :status, :string
    field :current_monthly_rent, :decimal
    field :current_lease_end_date, :date
    field :notice_date, :date
    field :move_out_date, :date
    field :next_lease_start_date, :date
    field :as_of, :date
  end
end

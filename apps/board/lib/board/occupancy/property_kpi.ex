defmodule Board.Occupancy.PropertyKpi do
  @moduledoc """
  One property's board KPIs today, read from the Rails-owned view
  `property_kpis_today` (CONTRACT.md §3). Rails defines the arithmetic (D-010);
  the board only reads the result columns. Read-only — no changeset.
  """
  use Ecto.Schema

  @primary_key {:property_id, :id, autogenerate: false}
  schema "property_kpis_today" do
    field :total_units, :integer
    field :occupied, :integer
    field :on_notice, :integer
    field :on_notice_rented, :integer
    field :vacant_rented, :integer
    field :vacant_available, :integer
    field :occupancy_pct, :decimal
    field :leased_pct, :decimal
    field :available_units, :integer
  end
end

defmodule Board.Occupancy.UnitTypeKpi do
  @moduledoc """
  One property's KPIs for a single bedroom count today, read from the Rails-owned
  view `property_unit_type_kpis_today` (CONTRACT.md §4). Same definitions as the
  property KPIs (D-010), applied within a unit type. Grain = (property_id,
  bedrooms). Read-only — no changeset.
  """
  use Ecto.Schema

  @primary_key false
  schema "property_unit_type_kpis_today" do
    field :property_id, :integer
    field :bedrooms, :integer
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

defmodule Board.Occupancy.Property do
  @moduledoc """
  A property, read from the Rails-owned `properties` table (CONTRACT.md: the
  board reader may `SELECT` `properties` for names). Read-only — the board
  connects as `board_reader` and never writes, so there is no changeset.
  """
  use Ecto.Schema

  alias Board.Occupancy.{PropertyKpi, UnitStatus}

  schema "properties" do
    field :name, :string
    field :address, :string
    field :city, :string
    field :state, :string
    field :sanity_slug, :string
    field :units_count, :integer

    # The KPI and status views are keyed by property_id; mapping them as
    # associations lets the index preload KPIs in one extra query, not N.
    has_one :kpis, PropertyKpi, foreign_key: :property_id
    has_many :unit_statuses, UnitStatus, foreign_key: :property_id
  end
end

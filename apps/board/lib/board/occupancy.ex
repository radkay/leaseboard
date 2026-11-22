defmodule Board.Occupancy do
  @moduledoc """
  Read side of the occupancy board.

  Queries the Rails-owned views (CONTRACT.md §2–§5) through `Board.Repo`, which
  connects as `board_reader` (SELECT only). The status and KPI rules live in
  Rails; this context only reads their results. All schemas are read-only — there
  are no changesets and the board never writes.
  """
  import Ecto.Query

  alias Board.Occupancy.{LeaseExpiration, Property, PropertyKpi, UnitStatus, UnitTypeKpi}
  alias Board.Repo

  @doc """
  Every property with its KPI row preloaded, ordered by name. Backs the `/`
  index. Two queries (properties, then their KPIs), never N+1.
  """
  def list_properties_with_kpis do
    Repo.all(from p in Property, order_by: p.name, preload: [:kpis])
  end

  @doc "A single property by id; raises `Ecto.NoResultsError` if it does not exist."
  def get_property!(id), do: Repo.get!(Property, id)

  @doc "A property's KPI row, or `nil` if the property has no row."
  def get_property_kpis(property_id), do: Repo.get(PropertyKpi, property_id)

  @doc """
  Every unit's status for one property, ordered by unit number — the source for
  the property's unit grid.
  """
  def list_unit_statuses(property_id) do
    Repo.all(
      from u in UnitStatus,
        where: u.property_id == ^property_id,
        order_by: u.unit_number
    )
  end

  @doc "A property's KPIs broken out by bedroom count, ordered studio-first."
  def list_unit_type_kpis(property_id) do
    Repo.all(
      from k in UnitTypeKpi,
        where: k.property_id == ^property_id,
        order_by: k.bedrooms
    )
  end

  @doc "A property's 12-month lease-expirations series, ordered by month."
  def list_lease_expirations(property_id) do
    Repo.all(
      from e in LeaseExpiration,
        where: e.property_id == ^property_id,
        order_by: e.month
    )
  end
end

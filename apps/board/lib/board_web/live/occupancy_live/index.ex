defmodule BoardWeb.OccupancyLive.Index do
  @moduledoc """
  The `/` board index: every property with its KPIs. Subscribes to each
  property's PubSub topic and re-queries when a lease changes there — no polling.
  """
  use BoardWeb, :live_view

  import BoardWeb.BoardComponents
  import BoardWeb.Charts

  alias Board.Occupancy

  @impl true
  def mount(_params, _session, socket) do
    properties = Occupancy.list_properties_with_kpis()

    if connected?(socket) do
      for property <- properties do
        Phoenix.PubSub.subscribe(Board.PubSub, "property:#{property.id}")
      end
    end

    {:ok, assign(socket, :properties, properties)}
  end

  @impl true
  def handle_info({:lease_changed, _property_id}, socket) do
    {:noreply, assign(socket, :properties, Occupancy.list_properties_with_kpis())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">Occupancy board</h1>
        <p class="mt-1 text-secondary">Live unit status across every property.</p>
      </div>

      <div class="grid gap-5 sm:grid-cols-2">
        <.link
          :for={property <- @properties}
          navigate={~p"/properties/#{property.id}"}
          class="block rounded-[2px] border border-base-300 p-5 transition-colors hover:border-primary"
        >
          <div class="flex items-baseline justify-between gap-2">
            <h2 class="text-lg font-semibold tracking-tight">{property.name}</h2>
            <span class="text-sm text-secondary">{property.city}, {property.state}</span>
          </div>

          <div class="mt-4 flex items-center gap-5">
            <.occupancy_donut kpis={property.kpis} class="w-24 shrink-0" />
            <div class="grid flex-1 grid-cols-3 gap-3">
              <.kpi_tile label="Occupancy" value={"#{property.kpis.occupancy_pct}%"} />
              <.kpi_tile label="Leased" value={"#{property.kpis.leased_pct}%"} />
              <.kpi_tile label="Available" value={"#{property.kpis.available_units}"} />
            </div>
          </div>

          <.status_bar kpis={property.kpis} class="mt-4" />

          <p class="mt-3 text-sm text-secondary">{property.kpis.total_units} units</p>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end

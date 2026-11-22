defmodule BoardWeb.OccupancyLive.Show do
  @moduledoc """
  `/properties/:id`: one property's unit grid, coloured by status, with a legend
  and KPIs. Subscribes to the property's PubSub topic and re-queries when a lease
  changes — no polling.
  """
  use BoardWeb, :live_view

  import BoardWeb.BoardComponents

  alias Board.Occupancy

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    property = Occupancy.get_property!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Board.PubSub, "property:#{property.id}")
    end

    {:ok, socket |> assign(:property, property) |> load_board()}
  end

  @impl true
  def handle_info({:lease_changed, _property_id}, socket) do
    {:noreply, load_board(socket)}
  end

  defp load_board(socket) do
    property_id = socket.assigns.property.id

    socket
    |> assign(:kpis, Occupancy.get_property_kpis(property_id))
    |> assign(:units, Occupancy.list_unit_statuses(property_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@property.name}
        <:subtitle>{@property.address}, {@property.city}, {@property.state}</:subtitle>
        <:actions>
          <.link navigate={~p"/"} class="text-sm hover:underline">← All properties</.link>
        </:actions>
      </.header>

      <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <.kpi_tile label="Occupancy" value={"#{@kpis.occupancy_pct}%"} />
        <.kpi_tile label="Leased" value={"#{@kpis.leased_pct}%"} />
        <.kpi_tile label="Available" value={"#{@kpis.available_units}"} />
        <.kpi_tile label="Units" value={"#{@kpis.total_units}"} />
      </div>

      <.status_legend class="mt-6" />

      <div class="mt-4 flex flex-wrap gap-1.5" role="list" aria-label="Units by status">
        <span
          :for={unit <- @units}
          role="listitem"
          aria-label={"Unit #{unit.unit_number}, #{status_label(unit.status)}"}
          title={"Unit #{unit.unit_number} — #{status_label(unit.status)}"}
          class="flex size-12 items-center justify-center rounded-md text-xs font-medium text-white"
          style={"background-color: #{status_color(unit.status)}"}
        >
          <span aria-hidden="true">{unit.unit_number}</span>
        </span>
      </div>
    </Layouts.app>
    """
  end
end

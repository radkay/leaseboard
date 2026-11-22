defmodule BoardWeb.OccupancyLive.Show do
  @moduledoc """
  `/properties/:id`: one property's board — KPIs, an occupancy doughnut and status
  bar, a filterable unit grid, a unit detail panel, and the unit-type and
  lease-expiration charts. All server-rendered SVG/CSS (D-013).

  Thin over `Board.Occupancy`: subscribes to the property's PubSub topic and
  re-queries on `{:lease_changed, _}` — no polling. A unit whose status changed
  on a re-query briefly flashes.
  """
  use BoardWeb, :live_view

  import BoardWeb.BoardComponents
  import BoardWeb.Charts

  alias Board.Occupancy

  @flash_ms 1200

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    property = Occupancy.get_property!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Board.PubSub, "property:#{property.id}")
    end

    {:ok,
     socket
     |> assign(property: property, filter: nil, selected_unit_id: nil, flashing: MapSet.new())
     |> load_board()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    # Clicking the active status clears the filter (toggle).
    filter = if socket.assigns.filter == status, do: nil, else: status
    {:noreply, assign(socket, :filter, filter)}
  end

  def handle_event("select_unit", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_unit_id, String.to_integer(id))}
  end

  def handle_event("close_unit", _params, socket) do
    {:noreply, assign(socket, :selected_unit_id, nil)}
  end

  @impl true
  def handle_info({:lease_changed, _property_id}, socket) do
    {:noreply, load_board(socket, flash_changes: true)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, assign(socket, :flashing, MapSet.new())}
  end

  defp load_board(socket, opts \\ []) do
    property_id = socket.assigns.property.id
    units = Occupancy.list_unit_statuses(property_id)

    flashing =
      if opts[:flash_changes] do
        changed = changed_unit_ids(socket.assigns[:units] || [], units)
        unless Enum.empty?(changed), do: Process.send_after(self(), :clear_flash, @flash_ms)
        MapSet.new(changed)
      else
        socket.assigns.flashing
      end

    socket
    |> assign(:kpis, Occupancy.get_property_kpis(property_id))
    |> assign(:units, units)
    |> assign(:unit_type_kpis, Occupancy.list_unit_type_kpis(property_id))
    |> assign(:expirations, Occupancy.list_lease_expirations(property_id))
    |> assign(:flashing, flashing)
  end

  defp changed_unit_ids(previous, current) do
    before = Map.new(previous, &{&1.unit_id, &1.status})

    for unit <- current, Map.get(before, unit.unit_id) not in [nil, unit.status], do: unit.unit_id
  end

  defp selected_unit(units, id), do: Enum.find(units, &(&1.unit_id == id))

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :selected, selected_unit(assigns.units, assigns.selected_unit_id))

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex items-baseline justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">{@property.name}</h1>
          <p class="mt-1 text-secondary">{@property.address}, {@property.city}, {@property.state}</p>
        </div>
        <.link navigate={~p"/"} class="shrink-0 text-sm text-primary hover:underline">
          ← All properties
        </.link>
      </div>

      <div class="flex flex-col gap-6 sm:flex-row sm:items-center">
        <.occupancy_donut kpis={@kpis} class="w-32 shrink-0" />
        <div class="grid flex-1 grid-cols-2 gap-5 sm:grid-cols-4">
          <.kpi_tile label="Occupancy" value={"#{@kpis.occupancy_pct}%"} />
          <.kpi_tile label="Leased" value={"#{@kpis.leased_pct}%"} />
          <.kpi_tile label="Available" value={"#{@kpis.available_units}"} />
          <.kpi_tile label="Units" value={"#{@kpis.total_units}"} />
        </div>
      </div>

      <.status_bar kpis={@kpis} />

      <section>
        <h2 class="mb-3 border-b border-base-300 pb-1 text-xs font-semibold uppercase tracking-wide text-secondary">
          Units
        </h2>
        <.status_legend interactive active={@filter} class="mb-4" />

        <div class="flex flex-wrap gap-1.5" role="list" aria-label="Units by status">
          <button
            :for={unit <- @units}
            id={"unit-#{unit.unit_id}"}
            type="button"
            role="listitem"
            phx-click="select_unit"
            phx-value-id={unit.unit_id}
            aria-label={"Unit #{unit.unit_number}, #{status_label(unit.status)}"}
            class={[
              "flex size-11 items-center justify-center rounded-[2px] text-xs font-medium text-white",
              @filter && @filter != unit.status && "opacity-25",
              MapSet.member?(@flashing, unit.unit_id) && "unit-flash",
              @selected_unit_id == unit.unit_id && "ring-2 ring-offset-2 ring-primary"
            ]}
            style={"background-color: #{status_color(unit.status)}"}
          >
            <span aria-hidden="true">{unit.unit_number}</span>
          </button>
        </div>
      </section>

      <.unit_detail :if={@selected} unit={@selected} />

      <section class="grid gap-10 lg:grid-cols-2">
        <div>
          <h2 class="mb-3 border-b border-base-300 pb-1 text-xs font-semibold uppercase tracking-wide text-secondary">
            Occupancy by unit type
          </h2>
          <.unit_type_chart kpis={@unit_type_kpis} />
        </div>
        <div>
          <h2 class="mb-3 border-b border-base-300 pb-1 text-xs font-semibold uppercase tracking-wide text-secondary">
            Lease expirations · next 12 months
          </h2>
          <.expirations_chart series={@expirations} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  # The side panel for one selected unit. Reads only the status view — no
  # resident identity is ever exposed (CONTRACT.md §2).
  attr :unit, :map, required: true

  defp unit_detail(assigns) do
    ~H"""
    <aside
      class="rounded-[2px] border border-base-300 p-5"
      aria-label={"Unit #{@unit.unit_number} detail"}
    >
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold tracking-tight">Unit {@unit.unit_number}</h2>
          <span
            class="mt-1 inline-block rounded-[2px] px-2 py-0.5 text-xs font-medium text-white"
            style={"background-color: #{status_color(@unit.status)}"}
          >
            {status_label(@unit.status)}
          </span>
        </div>
        <button
          type="button"
          phx-click="close_unit"
          class="text-sm text-secondary hover:text-base-content"
          aria-label="Close unit detail"
        >
          ✕
        </button>
      </div>

      <dl class="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
        <.detail label="Bedrooms" value={bedrooms_label(@unit.bedrooms)} />
        <.detail label="Market rent" value={money(@unit.market_rent)} />
        <.detail label="Current rent" value={money(@unit.current_monthly_rent)} />
        <.detail label="Lease end" value={date(@unit.current_lease_end_date)} />
        <.detail label="Notice date" value={date(@unit.notice_date)} />
        <.detail label="Move-out" value={date(@unit.move_out_date)} />
        <.detail label="Next lease start" value={date(@unit.next_lease_start_date)} />
      </dl>
    </aside>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail(assigns) do
    ~H"""
    <div>
      <dt class="text-secondary">{@label}</dt>
      <dd class="font-medium tabular-nums">{@value}</dd>
    </div>
    """
  end

  defp money(nil), do: "—"
  defp money(amount), do: "$#{Decimal.round(amount, 2)}"

  defp date(nil), do: "—"
  defp date(%Date{} = date), do: Calendar.strftime(date, "%b %-d, %Y")
end

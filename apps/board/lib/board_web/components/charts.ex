defmodule BoardWeb.Charts do
  @moduledoc """
  Server-rendered SVG/CSS chart components (D-013). No chart library and no JS:
  LiveView renders and diffs the SVG on the server, so every chart updates live
  with the rest of the page. Each chart ships a visually-hidden data table as its
  text alternative (`BoardComponents.data_table/1`).

  Colours for the status charts come from `BoardComponents` so the donut, the
  stacked bar, and the grid all agree.
  """
  use BoardWeb, :html

  import BoardWeb.BoardComponents

  # Expirations use their own two-colour scale (not the five statuses).
  @relet_color "#0d9488"
  @open_color "#d97706"

  @doc """
  A doughnut of the five statuses for one property. `kpis` is a struct with the
  per-status counts and `total_units`.
  """
  attr :kpis, :map, required: true
  attr :class, :any, default: nil

  def occupancy_donut(assigns) do
    counts = status_counts(assigns.kpis)
    total = assigns.kpis.total_units

    assigns =
      assign(assigns,
        arcs: donut_arcs(counts, total),
        total: total,
        occupancy_pct: percent(assigns.kpis.occupancy_pct),
        summary: counts_summary(counts, total),
        rows: Enum.map(counts, &[&1.label, &1.count])
      )

    ~H"""
    <div class={@class}>
      <svg viewBox="0 0 42 42" class="w-full max-w-[9rem]" role="img" aria-label={@summary}>
        <circle cx="21" cy="21" r="15.915" fill="none" stroke="#e5e7eb" stroke-width="5" />
        <circle
          :for={arc <- @arcs}
          cx="21"
          cy="21"
          r="15.915"
          fill="none"
          stroke={arc.color}
          stroke-width="5"
          stroke-dasharray={"#{arc.len} #{100 - arc.len}"}
          transform={"rotate(#{arc.angle} 21 21)"}
        />
        <text x="21" y="20.5" text-anchor="middle" font-size="7" font-weight="700" fill="currentColor">
          {@occupancy_pct}%
        </text>
        <text x="21" y="26" text-anchor="middle" font-size="3" fill="currentColor" opacity="0.6">
          occupied
        </text>
      </svg>
      <.data_table caption="Unit status breakdown" headers={["Status", "Units"]} rows={@rows} />
    </div>
    """
  end

  @doc "A horizontal stacked bar of the five status counts for one property."
  attr :kpis, :map, required: true
  attr :class, :any, default: nil

  def status_bar(assigns) do
    counts = status_counts(assigns.kpis)
    total = assigns.kpis.total_units

    assigns =
      assign(assigns,
        segments: for(s <- counts, s.count > 0, do: Map.put(s, :pct, s.count / total * 100)),
        summary: counts_summary(counts, total),
        rows: Enum.map(counts, &[&1.label, &1.count])
      )

    ~H"""
    <div class={@class}>
      <div
        class="flex h-3 w-full overflow-hidden rounded-full bg-base-200"
        role="img"
        aria-label={@summary}
      >
        <div
          :for={segment <- @segments}
          style={"width: #{segment.pct}%; background-color: #{segment.color}"}
          title={"#{segment.label}: #{segment.count}"}
        />
      </div>
      <.data_table caption="Unit status counts" headers={["Status", "Units"]} rows={@rows} />
    </div>
    """
  end

  @doc "Occupancy and leased % per bedroom type for a property. `kpis` is a list of UnitTypeKpi."
  attr :kpis, :list, required: true
  attr :class, :any, default: nil

  def unit_type_chart(assigns) do
    assigns =
      assign(assigns,
        rows:
          Enum.map(assigns.kpis, fn k ->
            [bedrooms_label(k.bedrooms), "#{k.occupancy_pct}%", "#{k.leased_pct}%", k.total_units]
          end)
      )

    ~H"""
    <div class={@class}>
      <div class="space-y-3">
        <div :for={k <- @kpis} class="text-sm">
          <div class="flex justify-between">
            <span class="font-medium">{bedrooms_label(k.bedrooms)}</span>
            <span class="opacity-60">{k.total_units} units</span>
          </div>
          <.pct_bar label="Occupancy" value={k.occupancy_pct} color={status_color("occupied")} />
          <.pct_bar label="Leased" value={k.leased_pct} color={status_color("vacant_rented")} />
        </div>
      </div>
      <.data_table
        caption="Occupancy and leased percent by unit type"
        headers={["Type", "Occupancy", "Leased", "Units"]}
        rows={@rows}
      />
    </div>
    """
  end

  @doc "A 12-month stacked bar chart of lease expirations. `series` is a list of LeaseExpiration."
  attr :series, :list, required: true
  attr :class, :any, default: nil

  def expirations_chart(assigns) do
    max = assigns.series |> Enum.map(& &1.expiring_total) |> Enum.max(fn -> 0 end) |> max(1)

    bars =
      assigns.series
      |> Enum.with_index()
      |> Enum.map(fn {e, i} ->
        %{
          x: 6 + i * 29,
          relet_h: e.expiring_renewed_or_relet / max * 90,
          open_h: e.expiring_open / max * 90,
          total_h: e.expiring_total / max * 90,
          label: Calendar.strftime(e.month, "%b"),
          total: e.expiring_total
        }
      end)

    assigns =
      assign(assigns,
        bars: bars,
        max: max,
        relet_color: @relet_color,
        open_color: @open_color,
        rows:
          Enum.map(assigns.series, fn e ->
            [
              Calendar.strftime(e.month, "%b %Y"),
              e.expiring_renewed_or_relet,
              e.expiring_open,
              e.expiring_total
            ]
          end)
      )

    ~H"""
    <div class={@class}>
      <div class="mb-2 flex gap-4 text-xs">
        <span class="flex items-center gap-1">
          <span
            class="inline-block size-3 rounded-sm"
            style={"background-color: #{@relet_color}"}
            aria-hidden="true"
          /> Renewed / re-let
        </span>
        <span class="flex items-center gap-1">
          <span
            class="inline-block size-3 rounded-sm"
            style={"background-color: #{@open_color}"}
            aria-hidden="true"
          /> Open
        </span>
      </div>

      <svg
        viewBox="0 0 352 128"
        class="w-full"
        role="img"
        aria-label={"Lease expirations over 12 months, peak #{@max} in a month."}
      >
        <line
          x1="2"
          y1="100"
          x2="350"
          y2="100"
          stroke="currentColor"
          stroke-width="0.5"
          opacity="0.3"
        />
        <g :for={bar <- @bars}>
          <rect x={bar.x} y={100 - bar.relet_h} width="18" height={bar.relet_h} fill={@relet_color} />
          <rect x={bar.x} y={100 - bar.total_h} width="18" height={bar.open_h} fill={@open_color} />
          <text
            x={bar.x + 9}
            y="112"
            text-anchor="middle"
            font-size="7"
            fill="currentColor"
            opacity="0.7"
          >
            {bar.label}
          </text>
          <text
            :if={bar.total > 0}
            x={bar.x + 9}
            y={96 - bar.total_h}
            text-anchor="middle"
            font-size="7"
            fill="currentColor"
          >
            {bar.total}
          </text>
        </g>
      </svg>

      <.data_table
        caption="Lease expirations by month"
        headers={["Month", "Renewed or re-let", "Open", "Total"]}
        rows={@rows}
      />
    </div>
    """
  end

  # A single labelled percentage bar (0–100).
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :color, :string, required: true

  defp pct_bar(assigns) do
    ~H"""
    <div class="mt-1 flex items-center gap-2">
      <span class="w-20 shrink-0 text-xs opacity-60">{@label}</span>
      <div class="h-2 flex-1 overflow-hidden rounded-full bg-base-200">
        <div class="h-full rounded-full" style={"width: #{@value}%; background-color: #{@color}"} />
      </div>
      <span class="w-14 shrink-0 text-right text-xs tabular-nums">{@value}%</span>
    </div>
    """
  end

  @doc "Human label for a bedroom count (0 = studio)."
  def bedrooms_label(0), do: "Studio"
  def bedrooms_label(n), do: "#{n} BR"

  # Cumulative arcs for the donut. viewBox is 42×42 with r=15.915 so the
  # circumference is ~100 and each dash length is a percentage. Each arc is a
  # full circle rotated to its start angle (−90° puts 0 at twelve o'clock).
  defp donut_arcs(_counts, 0), do: []

  defp donut_arcs(counts, total) do
    {arcs, _} =
      Enum.flat_map_reduce(counts, 0.0, fn s, acc ->
        frac = s.count / total

        if frac > 0 do
          {[%{color: s.color, len: frac * 100, angle: acc * 360 - 90}], acc + frac}
        else
          {[], acc + frac}
        end
      end)

    arcs
  end

  defp counts_summary(counts, total) do
    parts = Enum.map_join(counts, ", ", &"#{&1.count} #{String.downcase(&1.label)}")
    "#{parts}, of #{total} units."
  end

  defp percent(decimal), do: decimal |> Decimal.round() |> Decimal.to_integer()
end

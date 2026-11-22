defmodule BoardWeb.BoardComponents do
  @moduledoc """
  Presentation for the occupancy board: the status palette (shared by the grid,
  the legend, and — later — the SVG charts) plus small function components.

  Colours are plain hex so the same value drives an inline `background-color` on
  a grid cell and an SVG `fill`; Tailwind's JIT never sees a dynamically built
  class, so inline styling is both correct and consistent across both.
  """
  use BoardWeb, :html

  # The five derived statuses (CONTRACT.md §1), in a fixed display order. One
  # source of truth for label and colour.
  @statuses [
    %{key: "occupied", label: "Occupied", color: "#15803d"},
    %{key: "on_notice", label: "On notice", color: "#b45309"},
    %{key: "on_notice_rented", label: "On notice · re-let", color: "#0d9488"},
    %{key: "vacant_rented", label: "Vacant · rented", color: "#4f46e5"},
    %{key: "vacant_available", label: "Vacant · available", color: "#b91c1c"}
  ]

  @fallback %{key: "unknown", label: "Unknown", color: "#6b7280"}

  @doc "The ordered status metadata."
  def statuses, do: @statuses

  @doc "Metadata for one status key, with a grey fallback for anything unexpected."
  def status_meta(key), do: Enum.find(@statuses, %{@fallback | key: key}, &(&1.key == key))

  @doc "Human label for a status key."
  def status_label(key), do: status_meta(key).label

  @doc "Hex colour for a status key."
  def status_color(key), do: status_meta(key).color

  @doc """
  The five statuses with their counts pulled from a KPI struct/map (which has an
  integer field named for each status key), in display order.
  """
  def status_counts(counts) do
    for s <- @statuses do
      Map.put(s, :count, Map.fetch!(counts, String.to_existing_atom(s.key)))
    end
  end

  @doc "A single KPI figure with a caption."
  attr :label, :string, required: true
  attr :value, :string, required: true

  def kpi_tile(assigns) do
    ~H"""
    <div class="rounded-lg border border-base-300 px-3 py-2">
      <div class="text-xs uppercase tracking-wide opacity-60">{@label}</div>
      <div class="text-xl font-semibold tabular-nums">{@value}</div>
    </div>
    """
  end

  @doc """
  A visually-hidden data table — the text alternative for a chart. Screen readers
  and tests read the exact figures the chart draws.
  """
  attr :caption, :string, required: true
  attr :headers, :list, required: true
  attr :rows, :list, required: true, doc: "a list of rows, each a list of cell values"

  def data_table(assigns) do
    ~H"""
    <table class="sr-only">
      <caption>{@caption}</caption>
      <thead>
        <tr>
          <th :for={header <- @headers}>{header}</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows}>
          <td :for={cell <- row}>{cell}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc "A colour key mapping each swatch to its status label."
  attr :class, :string, default: nil
  attr :interactive, :boolean, default: false, doc: "render swatches as phx-click filter buttons"
  attr :active, :string, default: nil, doc: "the currently filtered status key, if any"

  def status_legend(%{interactive: true} = assigns) do
    ~H"""
    <div
      class={["flex flex-wrap items-center gap-2 text-sm", @class]}
      role="group"
      aria-label="Filter by status"
    >
      <button
        :for={s <- statuses()}
        type="button"
        phx-click="filter_status"
        phx-value-status={s.key}
        aria-pressed={to_string(@active == s.key)}
        class={[
          "flex items-center gap-2 rounded-full border px-2 py-0.5 transition-opacity",
          @active && @active != s.key && "opacity-40",
          @active == s.key && "border-primary font-medium"
        ]}
      >
        <span
          class="inline-block size-3 rounded-sm"
          style={"background-color: #{s.color}"}
          aria-hidden="true"
        />
        <span>{s.label}</span>
      </button>
    </div>
    """
  end

  def status_legend(assigns) do
    ~H"""
    <ul class={["flex flex-wrap gap-x-4 gap-y-1 text-sm", @class]}>
      <li :for={s <- statuses()} class="flex items-center gap-2">
        <span
          class="inline-block size-3 rounded-sm"
          style={"background-color: #{s.color}"}
          aria-hidden="true"
        />
        <span>{s.label}</span>
      </li>
    </ul>
    """
  end
end

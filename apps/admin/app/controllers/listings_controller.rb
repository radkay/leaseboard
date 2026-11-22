class ListingsController < ApplicationController
  # GET /listings/:slug — the public marketing page for a property. Content comes from
  # Sanity (cached, with a fallback); the available-unit count comes live from Postgres.
  def show
    @property = Property.find_by!(sanity_slug: params[:slug])
    @listing = Sanity.listing(@property.sanity_slug)
    @available_units = available_units_for(@property)
  end

  private

  # Served outside basic auth.
  def public_request?
    true
  end

  def available_units_for(property)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array(
        [ "SELECT available_units FROM property_kpis_today WHERE property_id = ?", property.id ]
      )
    ).to_i
  end
end

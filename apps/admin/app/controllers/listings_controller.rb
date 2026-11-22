class ListingsController < ApplicationController
  # GET /listings/:slug — the public marketing page for a property. Content comes from
  # Sanity (cached, with a fallback); the available-unit count comes live from Postgres.
  def show
    @property = Property.find_by!(sanity_slug: params[:slug])
    @listing = Sanity.listing(@property.sanity_slug)
    @available_units = @property.available_units
  end

  private

  # Served outside basic auth.
  def public_request?
    true
  end
end

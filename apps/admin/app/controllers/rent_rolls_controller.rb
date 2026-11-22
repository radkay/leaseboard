class RentRollsController < ApplicationController
  def show
    @properties = Property.order(:name)
    @property = Property.find_by(id: params[:property_id]) || @properties.first
    @as_of = parse_as_of(params[:as_of])
    @rent_roll = RentRoll.new(@property, as_of: @as_of) if @property

    respond_to do |format|
      format.html
      format.csv do
        filename = "rent-roll-#{@property.sanity_slug || @property.id}-#{@as_of.iso8601}.csv"
        send_data @rent_roll.to_csv, filename: filename, type: "text/csv"
      end
    end
  end

  private

  def parse_as_of(value)
    return Date.current if value.blank?

    Date.parse(value)
  rescue ArgumentError
    Date.current
  end
end

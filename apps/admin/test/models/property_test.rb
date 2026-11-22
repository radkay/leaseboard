require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "valid fixture is valid" do
    assert properties(:sunset).valid?
  end

  test "requires name, address, city and state" do
    property = Property.new
    assert_not property.valid?
    assert property.errors.key?(:name)
    assert property.errors.key?(:address)
    assert property.errors.key?(:city)
    assert property.errors.key?(:state)
  end

  test "sanity_slug is unique but optional" do
    assert Property.new(name: "A", address: "1 A St", city: "Austin", state: "TX").valid?

    dup = Property.new(name: "B", address: "2 B St", city: "Austin", state: "TX",
                       sanity_slug: properties(:sunset).sanity_slug)
    assert_not dup.valid?
    assert dup.errors.key?(:sanity_slug)
  end

  test "units_count counter cache tracks unit creation and destruction" do
    property = Property.create!(name: "X", address: "1 A St", city: "Austin", state: "TX")
    assert_equal 0, property.units_count

    unit = property.units.create!(number: "1", bedrooms: 1, bathrooms: 1, sq_ft: 500, market_rent: 1000)
    assert_equal 1, property.reload.units_count

    unit.destroy
    assert_equal 0, property.reload.units_count
  end
end

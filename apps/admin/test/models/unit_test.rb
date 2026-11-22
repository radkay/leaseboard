require "test_helper"

class UnitTest < ActiveSupport::TestCase
  test "valid fixture is valid" do
    assert units(:sunset_101).valid?
  end

  test "requires a property, number, bedrooms, bathrooms, sq_ft and market_rent" do
    unit = Unit.new
    assert_not unit.valid?
    assert unit.errors.key?(:property)
    assert unit.errors.key?(:number)
    assert unit.errors.key?(:bedrooms)
    assert unit.errors.key?(:bathrooms)
    assert unit.errors.key?(:sq_ft)
    assert unit.errors.key?(:market_rent)
  end

  test "number is unique within a property but not across properties" do
    dup = units(:sunset_101).dup
    assert_not dup.valid?
    assert dup.errors.key?(:number)

    other = Property.create!(name: "Other", address: "9 X St", city: "Austin", state: "TX")
    assert other.units.build(number: "101", bedrooms: 1, bathrooms: 1, sq_ft: 500, market_rent: 1000).valid?
  end

  test "bedrooms may be zero (studio) but not negative" do
    unit = units(:sunset_101)
    assert unit.studio?
    unit.bedrooms = -1
    assert_not unit.valid?
    assert unit.errors.key?(:bedrooms)
  end

  test "bathrooms, sq_ft and market_rent must be positive" do
    unit = units(:sunset_101)
    unit.bathrooms = 0
    unit.sq_ft = 0
    unit.market_rent = 0
    assert_not unit.valid?
    assert unit.errors.key?(:bathrooms)
    assert unit.errors.key?(:sq_ft)
    assert unit.errors.key?(:market_rent)
  end

  test "database rejects a non-positive market_rent" do
    unit = units(:sunset_101)
    assert_raises(ActiveRecord::StatementInvalid) do
      unit.update_column(:market_rent, 0)
    end
  end
end

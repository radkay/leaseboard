require "test_helper"

class ResidentTest < ActiveSupport::TestCase
  test "valid fixture is valid" do
    assert residents(:alice).valid?
  end

  test "requires first_name, last_name, email and phone" do
    resident = Resident.new
    assert_not resident.valid?
    assert resident.errors.key?(:first_name)
    assert resident.errors.key?(:last_name)
    assert resident.errors.key?(:email)
    assert resident.errors.key?(:phone)
  end

  test "email is unique case-insensitively" do
    dup = Resident.new(first_name: "A", last_name: "B",
                       email: residents(:alice).email.upcase, phone: "555-9999")
    assert_not dup.valid?
    assert dup.errors.key?(:email)
  end

  test "full_name joins first and last" do
    assert_equal "Alice Tenant", residents(:alice).full_name
  end
end

require "test_helper"

class SeedResetTest < ActiveSupport::TestCase
  test "seeding is permitted outside production regardless of the flag" do
    assert SeedReset.permitted?(production: false, override: nil)
    assert SeedReset.permitted?(production: false, override: "1")
  end

  test "seeding is blocked in production without the exact flag" do
    assert_not SeedReset.permitted?(production: true, override: nil)
    assert_not SeedReset.permitted?(production: true, override: "0")
    assert_not SeedReset.permitted?(production: true, override: "true")
  end

  test "seeding is permitted in production only with ALLOW_SEED_RESET=1" do
    assert SeedReset.permitted?(production: true, override: "1")
  end

  test "guard! aborts with a non-zero status when seeding isn't permitted" do
    error = assert_raises(SystemExit) { SeedReset.guard!(production: true, override: nil) }
    assert_not error.success?
  end

  test "guard! returns quietly when seeding is permitted" do
    assert_nil SeedReset.guard!(production: false, override: nil)
  end
end

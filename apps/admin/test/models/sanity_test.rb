require "test_helper"

class SanityTest < ActiveSupport::TestCase
  # A fully configured Sanity project, for the tests that need `configured?` to be true.
  CONFIG = {
    "SANITY_PROJECT_ID" => "proj123",
    "SANITY_DATASET" => "production",
    "SANITY_API_VERSION" => "2024-01-01"
  }.freeze

  setup { Rails.cache.clear }

  test "image_url builds a Sanity CDN url from an asset ref" do
    with_env("SANITY_PROJECT_ID" => "proj123", "SANITY_DATASET" => "production") do
      assert_equal "https://cdn.sanity.io/images/proj123/production/abc123-800x600.jpg",
        Sanity.image_url("image-abc123-800x600-jpg")
    end
  end

  test "image_url is nil for a blank or malformed ref" do
    assert_nil Sanity.image_url(nil)
    assert_nil Sanity.image_url("not-an-image")
  end

  test "listing is nil and makes no network call when Sanity isn't configured" do
    assert_not Sanity.configured?, "SANITY_* should be unset in the test environment"

    with_sanity_transport(->(_uri) { flunk "transport should not be called when unconfigured" }) do
      assert_nil Sanity.listing("sunset-apartments")
    end
  end

  test "listing caches: the transport runs once across two calls" do
    calls = 0
    with_env(CONFIG) do
      with_sanity_transport(->(_uri) { calls += 1; { "result" => { "headline" => "X" } }.to_json }) do
        2.times { Sanity.listing("x") }
      end
    end
    assert_equal 1, calls
  end

  test "fetch_listing returns nil when the transport yields nothing" do
    with_env(CONFIG) do
      with_sanity_transport(->(_uri) { nil }) do
        assert_nil Sanity.fetch_listing("x")
      end
    end
  end

  test "fetch_listing returns nil on malformed JSON rather than raising" do
    with_env(CONFIG) do
      with_sanity_transport(->(_uri) { "not json" }) do
        assert_nil Sanity.fetch_listing("x")
      end
    end
  end

  test "fetch_listing logs a warning when it falls back" do
    logs = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logs)

    with_env(CONFIG) do
      with_sanity_transport(->(_uri) { nil }) { Sanity.fetch_listing("maple-court") }
      with_sanity_transport(->(_uri) { "not json" }) { Sanity.fetch_listing("riverside-lofts") }
    end

    assert_match(/no content returned for listing "maple-court"/, logs.string)
    assert_match(/malformed JSON for listing "riverside-lofts"/, logs.string)
  ensure
    Rails.logger = original
  end

  test "the default transport returns nil instead of raising on a dead connection" do
    # 127.0.0.1:1 refuses immediately — a local socket, never a call to Sanity — so this
    # exercises http_get's rescue offline and deterministically.
    assert_nil Sanity.http_get(URI("https://127.0.0.1:1/"))
  end
end

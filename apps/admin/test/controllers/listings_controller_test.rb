require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  CONFIG = {
    "SANITY_PROJECT_ID" => "proj123",
    "SANITY_DATASET" => "production",
    "SANITY_API_VERSION" => "2024-01-01"
  }.freeze

  LISTING = {
    "headline" => "Bright studios at Sunset",
    "description" => [
      { "_type" => "block", "style" => "normal", "children" => [
        { "text" => "Welcome ", "marks" => [] },
        { "text" => "home", "marks" => [ "strong" ] },
        { "text" => ".", "marks" => [] }
      ] },
      { "_type" => "block", "style" => "h2", "children" => [ { "text" => "Features", "marks" => [] } ] },
      { "_type" => "block", "listItem" => "bullet", "children" => [ { "text" => "Rooftop deck", "marks" => [] } ] }
    ],
    "amenities" => [ "Gym", "Parking" ],
    "photos" => [ { "ref" => "image-abc123-800x600-jpg", "alt" => "Living room" } ]
  }.freeze

  setup do
    @property = properties(:sunset)
    Rails.cache.clear
  end

  test "renders the listing content from Sanity" do
    with_sanity(LISTING) { get listing_url(slug: @property.sanity_slug) }

    assert_response :success
    assert_select "h1", "Bright studios at Sunset"
    assert_select "strong", "home"
    assert_select "h2", "Features"
    assert_select "li", text: "Gym"
    assert_select "li", text: "Rooftop deck"
    assert_select "img[alt=?]", "Living room"
  end

  test "is public: no basic auth required" do
    wrong = ActionController::HttpAuthentication::Basic.encode_credentials("nobody", "nope")
    get listing_url(slug: @property.sanity_slug), headers: { "Authorization" => wrong }
    assert_response :success
  end

  test "falls back to the property record when Sanity isn't configured" do
    get listing_url(slug: @property.sanity_slug)

    assert_response :success
    assert_select "h1", @property.name
    assert_match @property.city, response.body
  end

  test "falls back when Sanity is configured but unreachable" do
    with_sanity(nil) { get listing_url(slug: @property.sanity_slug) }

    assert_response :success
    assert_select "h1", @property.name
  end

  test "caches Sanity content: a second request within 5 minutes doesn't call Sanity" do
    calls = 0
    with_env(CONFIG) do
      with_sanity_transport(->(_uri) { calls += 1; { "result" => LISTING }.to_json }) do
        get listing_url(slug: @property.sanity_slug)
        get listing_url(slug: @property.sanity_slug)
      end
    end
    assert_equal 1, calls
    assert_response :success
  end

  test "shows the live available-unit count from property_kpis_today" do
    get listing_url(slug: @property.sanity_slug)

    assert_response :success
    assert_select "p.listing-availability"
  end

  test "unknown slug is 404" do
    get listing_url(slug: "no-such-property")
    assert_response :not_found
  end

  private

  # Render the page with Sanity configured and its transport returning `result` (a listing
  # hash, or nil to simulate an outage). No network call, no mocking gem.
  def with_sanity(result)
    body = result.nil? ? nil : { "result" => result }.to_json
    with_env(CONFIG) do
      with_sanity_transport(->(_uri) { body }) { yield }
    end
  end
end

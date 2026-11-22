require "net/http"

# The one module that holds every GROQ query and all Sanity HTTP access (CLAUDE.md's Sanity
# rule). It talks to Sanity's query API over Net::HTTP with short open/read timeouts, caches
# results for five minutes, and returns nil on anything going wrong (not configured, timeout,
# network error, non-2xx, bad JSON) so callers fall back to the property record.
module Sanity
  TIMEOUT = 2 # seconds, for both open and read
  CACHE_TTL = 5.minutes

  # Fetch one propertyListing by slug, projecting image asset refs + alt text (SPEC §6).
  LISTING_QUERY = <<~GROQ.squish
    *[_type == "propertyListing" && slug.current == $slug][0]{
      headline,
      description,
      amenities,
      "photos": photos[]{ "ref": asset._ref, alt }
    }
  GROQ

  class << self
    # The network boundary, as a replaceable callable: (URI) -> response body String, or
    # nil on any failure. Defaults to the Net::HTTP fetch below. Tests assign a stub here
    # so the suite exercises the real parsing/caching/fallback without a network call (and
    # without a mocking gem — Minitest 6 dropped Minitest::Mock). Assign nil to restore.
    attr_writer :transport

    def transport
      @transport ||= method(:http_get)
    end
  end

  module_function

  def configured?
    [ project_id, dataset, api_version ].all?(&:present?)
  end

  # Cached listing hash, or nil (then render fallback). Failures aren't cached (skip_nil), so
  # a transient Sanity outage is retried on the next request rather than pinned for 5 minutes.
  def listing(slug)
    return nil unless configured? && slug.present?

    Rails.cache.fetch("sanity/listing/#{dataset}/#{slug}", expires_in: CACHE_TTL, skip_nil: true) do
      fetch_listing(slug)
    end
  end

  def fetch_listing(slug)
    body = transport.call(query_uri(slug))
    body && JSON.parse(body)["result"]
  rescue JSON::ParserError
    nil
  end

  # Build a Sanity CDN image URL from an asset ref like "image-abc123-800x600-jpg".
  def image_url(ref)
    _type, id, dimensions, format = ref.to_s.split("-")
    return nil unless _type == "image" && id && dimensions && format

    "https://cdn.sanity.io/images/#{project_id}/#{dataset}/#{id}-#{dimensions}.#{format}"
  end

  def project_id = ENV["SANITY_PROJECT_ID"]
  def dataset = ENV["SANITY_DATASET"]
  def api_version = ENV["SANITY_API_VERSION"]

  def query_uri(slug)
    URI::HTTPS.build(
      host: "#{project_id}.api.sanity.io",
      path: "/v#{api_version}/data/query/#{dataset}",
      query: URI.encode_www_form(query: LISTING_QUERY, "$slug": slug.to_json)
    )
  end

  # Default transport. GETs the URI with short open/read timeouts and returns the body only
  # on a 2xx; any timeout, connection error, or non-2xx becomes nil (then callers fall back).
  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    response = http.get(uri.request_uri)
    response.body if response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    nil
  end
end

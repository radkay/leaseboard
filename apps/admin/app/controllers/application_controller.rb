class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # HTTP basic auth is the full extent of admin authentication (SPEC §8). Credentials
  # come from the environment; the local fallbacks are placeholders, not secrets, and
  # production must set ADMIN_USERNAME / ADMIN_PASSWORD (Render env vars).
  http_basic_authenticate_with(
    name: ENV["ADMIN_USERNAME"] || "admin",
    password: ENV["ADMIN_PASSWORD"] || "change-me"
  )
end

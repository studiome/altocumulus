# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# With RAILS_RELATIVE_URL_ROOT=/subpath the app is mounted there (the front
# proxy passes the prefix through unchanged). Rack then sets SCRIPT_NAME, so
# URL and asset helpers emit the prefix.
map Rails.application.config.relative_url_root.presence || "/" do
  run Rails.application
end
Rails.application.load_server

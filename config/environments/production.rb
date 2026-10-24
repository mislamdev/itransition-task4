require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # NOTE: the application is published through a TLS terminating proxy - a
  # tunnel (cloudflared) on this machine or the edge of Render.
  # The Rails process itself listens on the loopback interface only, so the
  # plain HTTP hop between the proxy and Rails stays inside the machine.
  #
  # IMPORTANT: both switches are read from the environment:
  #   ASSUME_SSL=true  - the proxy terminates the TLS and sends the header
  #                      `X-Forwarded-Proto: https` (Render does this).
  #   FORCE_SSL=true   - the proxy does NOT redirect to HTTPS, therefore Rails
  #                      has to do it (Render redirects on its own).
  # On this machine both are off: the tunnel sends the header and redirects
  # itself.
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "false") == "true"
  config.force_ssl = ENV.fetch("FORCE_SSL", "false") == "true"

  # The secure cookie flag is kept, the proxy uses HTTPS.
  config.action_dispatch.cookies_same_site_protection = :lax

  # NOTE: the static files (the assets) are served by the application itself.
  # IMPORTANT: Render (and every other platform) sets this variable - without
  # it the stylesheets and the scripts would not be found.
  config.public_file_server.enabled = ENV.fetch("RAILS_SERVE_STATIC_FILES", "true") == "true"

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # NOTE: the public host name of the tunnel changes with every start, therefore
  # the check is limited to the loopback addresses - the tunnel is the only way
  # into the application and it listens on 127.0.0.1.
  config.hosts.clear
  config.hosts << /.*\.trycloudflare\.com/
  config.hosts << "127.0.0.1"
  config.hosts << "localhost"

  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end

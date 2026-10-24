require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Task4
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # NOTE: the CSRF protection is configured by hand in ApplicationController,
    # because the JSON API has to skip it for the service calls that carry the
    # API token (those requests do not use the cookies of the browser).
    # IMPORTANT: the browser requests are still protected - the javascript of
    # the panel sends the X-CSRF-Token header.
    config.action_controller.default_protect_from_forgery = false

    # NOTE: the "per form" CSRF tokens are switched off on purpose.
    #
    # IMPORTANT: the toolbar of the user table is ONE form that is submitted to
    # THREE different endpoints (the HTML attribute `formaction` of the
    # buttons: block, unblock, delete). A per form token is bound to the
    # action of the form, therefore it would be rejected by the other two
    # endpoints. The token of the session is valid for every action of the
    # session - and it is still masked and single use.
    config.action_controller.per_form_csrf_tokens = false

    # NOTE: the panel is a business application, not a landing page.
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

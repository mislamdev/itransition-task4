ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # NOTE: the tests run in ONE process. The suite is small (less than a
    # second) and every worker would need its own database - with PostgreSQL
    # the parallel setup of the databases is not worth the trouble here.
    parallelize(workers: 1)

    # NOTE: no fixtures - the tests create their own data, so that the
    # expectations are visible inside the test file.

    # Small helper: creates a user with a password of one character.
    # IMPORTANT: the task allows ANY non-empty password.
    def create_user(name: "Test User", email: nil, password: "a", blocked: false, last_login_at: nil)
      email ||= "user#{SecureRandom.hex(4)}@example.com"
      User.create!(
        name: name,
        email: email,
        password: password,
        password_confirmation: password,
        blocked: blocked,
        last_login_at: last_login_at,
        last_activity_at: last_login_at
      )
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # Small helper: signs a user in through the real login form.
    def sign_in(user, password: "a")
      post login_path, params: { email: user.email, password: password, authenticity_token: csrf_token }
    end

    # Small helper: the CSRF token of the last rendered page.
    #
    # IMPORTANT: the CSRF protection is enabled in the test environment, so
    # every write request has to send the token - exactly like the browser
    # does it. If no page was loaded yet, a page is loaded here.
    def csrf_token
      token = extract_csrf_token(@response&.body)
      return token if token.present?

      # NOTE: the login form is public, therefore it always works.
      get login_path
      token = extract_csrf_token(@response.body)
      return token if token.present?

      # NOTE: a signed in user is redirected to the table - it has the token.
      get users_path
      extract_csrf_token(@response.body)
    end

    # Small helper: reads the token out of a page.
    def extract_csrf_token(html)
      html.to_s[/name="csrf-token" content="([^"]+)"/, 1] ||
        html.to_s[/name="authenticity_token" value="([^"]+)"/, 1]
    end

    # Small helper: a POST with the CSRF token (like the toolbar of the table
    # does it).
    def post_with_csrf(path, params = {}, headers: {})
      post path, params: params.merge(authenticity_token: csrf_token), headers: headers
    end

    # Small helper: a JSON request with the CSRF token in the header.
    def post_json_with_csrf(path, payload = {})
      post path, params: payload.to_json,
           headers: { "Content-Type" => "application/json", "X-CSRF-Token" => csrf_token }
    end
  end
end

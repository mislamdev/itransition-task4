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
      post login_path, params: { email: user.email, password: password }
    end
  end
end

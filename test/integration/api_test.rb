# frozen_string_literal: true

require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(name: "Owner", email: "owner@example.com")
    @alice = create_user(name: "Alice", email: "alice@example.com", last_login_at: 3.days.ago)
    @sarah = create_user(name: "Sarah", email: "sarah@gmail.com", last_login_at: 1.hour.ago)
    @peter = create_user(name: "Peter", email: "peter@gmail.com", blocked: true)
    sign_in(@owner)
  end

  # NOTE: the API is protected like the rest of the application.
  test "the API rejects a request without a session" do
    delete logout_path, params: { authenticity_token: csrf_token }
    get "/api/v1/users"

    assert_response :unauthorized
  end

  test "the API returns the list of users" do
    get "/api/v1/users"

    assert_response :success
    body = response.parsed_body
    assert_equal 4, body["total_count"]
    assert_equal 4, body["users"].size
    assert_includes body["users"].map { |user| user["email"] }, "alice@example.com"
    # NOTE: the default order is "the most recent login first".
    assert_equal "owner@example.com", body["users"].first["email"]
  end

  test "the API filters the users by an e-mail prefix" do
    get "/api/v1/users", params: { email_prefixes: "s, p" }

    body = response.parsed_body
    assert_equal 2, body["total_count"]
    # NOTE: the default order is "the most recent login first", Peter has
    # never logged in and is therefore the last one.
    assert_equal ["sarah@gmail.com", "peter@gmail.com"], body["users"].map { |u| u["email"] }
  end

  # IMPORTANT: the numbers are calculated by the database.
  test "the API returns the statistics" do
    get "/api/v1/users/stats"

    body = response.parsed_body
    assert_equal 4, body["totals"]["users"]
    assert_equal 3, body["totals"]["active"]
    assert_equal 1, body["totals"]["blocked"]
    # NOTE: the owner has signed in during the setup, therefore three accounts
    # have a login time and one has never logged in.
    assert_equal 3, body["activity"]["last_login_ever"]
    assert_equal 1, body["activity"]["never_logged_in"]
  end

  test "the API groups the users by domain" do
    get "/api/v1/users/stats", params: { group_by: "domain" }

    body = response.parsed_body
    groups = body["groups"].to_h { |group| [group["key"], group["count"]] }
    assert_equal 2, groups["example.com"]
    assert_equal 2, groups["gmail.com"]
  end

  test "the bulk API blocks the selected users" do
    post_json_with_csrf "/api/v1/users/bulk_block", user_ids: [@alice.id]

    assert_response :success
    assert_equal 1, response.parsed_body["count"]
    assert @alice.reload.blocked?
  end

  # NOTE: the service token is accepted as well - this is how the assistant
  # calls the API.
  test "the API accepts the service token" do
    delete logout_path
    get "/api/v1/users", headers: { "Authorization" => "Bearer #{Assistant.api_token}" }

    assert_response :success
  end
end

# frozen_string_literal: true

require "test_helper"

class AssistantTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(name: "Owner", email: "owner@example.com")
    @alice = create_user(name: "Alice", email: "alice@example.com", last_login_at: 3.days.ago)
    @sarah = create_user(name: "Sarah", email: "sarah@gmail.com", last_login_at: 1.hour.ago)
    @peter = create_user(name: "Peter", email: "peter@gmail.com", blocked: true)
    sign_in(@owner)
  end

  # ---------------------------------------------------------------------------
  # PART 2: questions about the data.
  # ---------------------------------------------------------------------------
  test "the assistant counts the blocked users" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "How many users are blocked?"

    assert_response :success
    body = response.parsed_body
    assert_match(/1 blocked user/, body["answer"])
    assert_equal "count_users", body["plan"]["intent"]
  end

  test "the assistant counts all the users" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "how many users are there in total?"

    body = response.parsed_body
    assert_match(/4 users/, body["answer"])
  end

  test "the assistant counts the users that logged in during the last 7 days" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "how many users logged in during the last 7 days?"

    body = response.parsed_body
    # NOTE: the owner has signed in during the setup, therefore three accounts
    # have a login time within the last 7 days.
    assert_match(/3 users/, body["answer"])
  end

  test "the assistant counts the users that never logged in" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "how many users have never logged in?"

    body = response.parsed_body
    # NOTE: the owner has signed in during the setup, therefore only the
    # blocked account of Peter has never logged in.
    assert_match(/1 user has never logged in/, body["answer"])
  end

  # NOTE: the question about the registration uses the registration counter,
  # not the login counter.
  test "the assistant counts the registered users of the last 7 days" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "how many users registered this week?"

    body = response.parsed_body
    assert_equal "registration", body["plan"]["metric"]
    assert_match(/registered during the last 7 days/, body["answer"])
    assert_equal User.where(created_at: 7.days.ago..).count, body["data"]["activity"]["registered_7d"]
  end

  test "the assistant lists the users with an e-mail prefix" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "show the users whose e-mail starts with s"

    body = response.parsed_body
    assert_match(/sarah@gmail\.com/, body["answer"])
    assert_no_match(/peter@gmail\.com/, body["answer"])
  end

  test "the assistant reports the breakdown by domain" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "how many users are there per e-mail domain?"

    body = response.parsed_body
    assert_match(/example\.com: 2/, body["answer"])
    assert_match(/gmail\.com: 2/, body["answer"])
  end

  test "the assistant describes one user" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "what is the status of sarah@gmail.com?"

    body = response.parsed_body
    assert_match(/Sarah/, body["answer"])
    assert_match(/status: active/, body["answer"])
  end

  test "an empty question is rejected" do
    post_json_with_csrf "/api/v1/assistant/ask", question: ""

    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # PART 3: commands that control the dashboard.
  # ---------------------------------------------------------------------------
  test "the assistant selects the users with e-mails started with s or p" do
    post_json_with_csrf "/api/v1/assistant/command", command: "select users with e-mails started with s or p"

    assert_response :success
    body = response.parsed_body
    select_action = body["ui_actions"].find { |action| action["type"] == "select_users" }

    assert select_action, "the assistant did not return a selection"
    assert_equal [@sarah.id, @peter.id].sort, select_action["ids"].sort
    assert_equal 2, select_action["count"]
  end

  test "the assistant blocks the selected users" do
    post_json_with_csrf "/api/v1/assistant/command",
                        command: "block the selected users",
                        selected_ids: [@alice.id]

    body = response.parsed_body
    assert_match(/Blocked 1 user/, body["answer"])
    assert @alice.reload.blocked?
  end

  test "the assistant deletes the selected users" do
    assert_difference "User.count", -1 do
      post_json_with_csrf "/api/v1/assistant/command",
                          command: "delete the selected users",
                          selected_ids: [@alice.id]
    end

    body = response.parsed_body
    assert_match(/Deleted 1 user/, body["answer"])
  end

  test "the assistant clears the selection" do
    post_json_with_csrf "/api/v1/assistant/command", command: "clear the selection"

    body = response.parsed_body
    assert body["ui_actions"].any? { |action| action["type"] == "clear_selection" }
    assert_match(/Selection cleared/, body["answer"])
  end

  test "the assistant changes the sort order" do
    post_json_with_csrf "/api/v1/assistant/command", command: "sort by e-mail"

    body = response.parsed_body
    sort_action = body["ui_actions"].find { |action| action["type"] == "sort_by" }
    assert_equal "email", sort_action["sort"]
  end

  test "the assistant filters the table" do
    post_json_with_csrf "/api/v1/assistant/command", command: "show only blocked users"

    body = response.parsed_body
    filter_action = body["ui_actions"].find { |action| action["type"] == "set_filter" }
    assert_equal "blocked", filter_action["filters"]["status"]
  end

  # NOTE: the answer of the assistant is never produced by a language model -
  # the numbers come from the database.
  test "the answer contains the numbers of the database and not of a model" do
    post_json_with_csrf "/api/v1/assistant/ask", question: "how many users are blocked?"

    body = response.parsed_body
    assert_equal User.blocked.count, body["data"]["totals"]["blocked"]
  end

  test "the assistant page is rendered" do
    get assistant_path

    assert_response :success
    assert_select "form#assistant-form", 1
  end
end

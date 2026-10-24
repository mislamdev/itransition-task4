# frozen_string_literal: true

require "test_helper"

class UserActivityTest < ActiveSupport::TestCase
  # NOTE: the history is the source of the small bar chart under the "last
  # activity" column of the table.
  test "an activity is recorded" do
    user = create_user

    assert_difference "UserActivity.count", 1 do
      UserActivity.record(user)
    end

    activity = UserActivity.order(:id).last
    assert_equal user.id, activity.user_id
    assert_in_delta Time.current.to_f, activity.occurred_at.to_f, 5
  end

  # IMPORTANT: a user that browses the table must not fill the history with
  # thousands of rows - at most one entry per minute.
  test "the activity is recorded at most once per minute" do
    user = create_user

    UserActivity.record(user)

    assert_no_difference "UserActivity.count" do
      UserActivity.record(user)
      UserActivity.record(user)
    end
  end

  test "the history belongs to the account and is deleted with it" do
    user = create_user
    UserActivity.record(user)

    assert_difference "UserActivity.count", -1 do
      user.destroy!
    end
  end

  # NOTE: the counters of the chart - one bar per day of the last 14 days.
  test "the history is counted per day" do
    user = create_user
    today = Time.current.beginning_of_day
    yesterday = 1.day.ago.beginning_of_day

    UserActivity.create!(user: user, occurred_at: today + 2.hours)
    UserActivity.create!(user: user, occurred_at: today + 3.hours)
    UserActivity.create!(user: user, occurred_at: yesterday + 5.hours)

    counts = ActivityHistory.for_users([user])

    assert_equal ActivityHistory::DAYS, counts[user.id].size
    assert_equal 2, counts[user.id].last
    assert_equal 1, counts[user.id][-2]
    assert_equal 0, counts[user.id].first
  end

  # IMPORTANT: the counters of the whole table are computed with ONE query.
  test "the counters of many users are computed with one query" do
    users = Array.new(3) { |index| create_user(email: "history#{index}@example.com") }
    UserActivity.create!(user: users.first, occurred_at: Time.current)

    counts = nil
    queries = 0
    counter = ->(_name, _start, _finish, _id, _payload) { queries += 1 }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      counts = ActivityHistory.for_users(users)
    end

    assert_equal 3, counts.size
    assert_equal 1, counts[users.first.id].last
    assert_equal 0, counts[users.last.id].last
    assert_equal 1, queries
  end
end

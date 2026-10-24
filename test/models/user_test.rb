# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  # NOTE: the e-mail is normalised, therefore the unique index on the plain
  # column is enough to make the uniqueness case insensitive.
  test "the email is downcased and trimmed" do
    user = User.create!(name: "Bob", email: "  Bob@Example.COM ", password: "a", password_confirmation: "a")
    assert_equal "bob@example.com", user.email
  end

  # IMPORTANT: the unique index of the database is the real guarantee. The
  # validation only produces the friendly message.
  test "the email must be unique" do
    create_user(email: "taken@example.com")
    duplicate = User.new(name: "Other", email: "taken@example.com", password: "a", password_confirmation: "a")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages.join, "has already been taken"
  end

  # IMPORTANT: the database rejects a second row with the same e-mail even if
  # the application code is bypassed completely.
  test "the database itself rejects a duplicate email" do
    create_user(email: "duplicate@example.com")

    assert_raises ActiveRecord::RecordNotUnique do
      User.connection.execute(
        "INSERT INTO users (name, email, password_digest, blocked, created_at, updated_at) " \
        "VALUES ('Raw', 'DUPLICATE@example.com', 'x', false, now(), now())"
      )
    end
  end

  # NOTE: any non-empty password is allowed - even a single character.
  test "a one character password is accepted" do
    user = User.new(name: "Short", email: "short@example.com", password: "a", password_confirmation: "a")

    assert user.valid?
    assert user.authenticate("a")
  end

  test "an empty password is rejected" do
    user = User.new(name: "Empty", email: "empty@example.com", password: "", password_confirmation: "")

    assert_not user.valid?
    assert_includes user.errors.full_messages.join, "Password"
  end

  test "the status label describes the account" do
    active = create_user(blocked: false)
    blocked = create_user(blocked: true)

    assert_equal "Active", active.status_label
    assert_equal "Blocked", blocked.status_label
  end

  # NOTE: the scopes are used by the table and by the API.
  test "the scopes separate the active and the blocked accounts" do
    create_user(blocked: true)
    create_user(blocked: false)

    assert_equal 1, User.blocked.count
    assert_equal 1, User.active.count
  end
end

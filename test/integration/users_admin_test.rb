# frozen_string_literal: true

require "test_helper"

class UsersAdminTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(name: "Owner", email: "owner@example.com")
    @alice = create_user(name: "Alice", email: "alice@example.com", last_login_at: 3.days.ago)
    @bob = create_user(name: "Bob", email: "bob@example.com", last_login_at: 1.hour.ago, blocked: true)
    @carol = create_user(name: "Carol", email: "carol@example.com", last_login_at: nil)
    sign_in(@user)
  end

  # NOTE: the table has a header checkbox and one checkbox per row.
  test "the table contains a selection checkbox in the header and in every row" do
    get users_path

    assert_response :success
    assert_select "table#users-table thead input[type=checkbox]#select-all", 1
    assert_select "table#users-table tbody tr[data-user-id]", 4
    assert_select "table#users-table tbody input.row-checkbox", 4
  end

  # IMPORTANT: the header checkbox must NOT have a label.
  test "the header checkbox has no label" do
    get users_path

    assert_select "table#users-table thead th label", 0
  end

  # IMPORTANT: "NO BUTTONS IN THE DATA ROWS".
  test "there is no button inside a data row" do
    get users_path

    assert_select "table#users-table tbody button", 0
    assert_select "table#users-table tbody a", 0
  end

  # IMPORTANT: the toolbar is always visible and it holds the three actions.
  test "the toolbar with the three actions is above the table" do
    get users_path

    assert_select "form#selection-form .card-header", 1
    assert_select "button#block-selected", text: /Block/i
    assert_select "button#unblock-selected i.bi", 1
    assert_select "button#delete-selected i.bi", 1
    # NOTE: the block button has a text, the other two are icons.
    assert_select "button#unblock-selected", text: /\A\s*\z/
  end

  # IMPORTANT: the data in the table is sorted by the last login time.
  test "the table is sorted by the last login time" do
    get users_path, params: { sort: "last_login_at", direction: "desc" }

    emails = css_select("table#users-table tbody tr td:nth-child(3)").map(&:text)
    # NOTE: the owner has just signed in, therefore it is the most recent one;
    # Carol never logged in and is therefore at the bottom.
    assert_equal ["owner@example.com", "bob@example.com", "alice@example.com", "carol@example.com"], emails
  end

  test "the table can be sorted by name" do
    get users_path, params: { sort: "name", direction: "asc" }

    emails = css_select("table#users-table tbody tr td:nth-child(3)").map(&:text)
    assert_equal ["alice@example.com", "bob@example.com", "carol@example.com", "owner@example.com"], emails
  end

  # NOTE: the sorted column has to be visible - the label is marked and the
  # icon shows the direction of the order.
  test "the sorted column is marked" do
    get users_path, params: { sort: "email", direction: "asc" }

    assert_select "table#users-table thead th[aria-sort=?]", "ascending" do
      assert_select "a.table-sort-link.is-active", text: /E-mail/
      assert_select "i.bi-chevron-up"
    end

    assert_select "table#users-table thead th[aria-sort=?]", "none", count: 4
  end

  # NOTE: the toolbar action "Block".
  test "the toolbar blocks the selected users" do
    post_with_csrf block_users_path, { user_ids: [@alice.id, @carol.id] }

    assert_redirected_to users_path
    assert @alice.reload.blocked?
    assert @carol.reload.blocked?
    assert @bob.reload.blocked? # it was blocked before, it stays blocked
    follow_redirect!
    assert_select ".alert-success", text: /2 users blocked/i
  end

  # NOTE: the toolbar action "Unblock".
  test "the toolbar unblocks the selected users" do
    post_with_csrf unblock_users_path, { user_ids: [@bob.id] }

    assert_redirected_to users_path
    assert_not @bob.reload.blocked?
    follow_redirect!
    assert_select ".alert-success", text: /1 user unblocked/i
  end

  # IMPORTANT: the rows are really deleted, they are not flagged.
  test "the toolbar deletes the selected users" do
    assert_difference "User.count", -2 do
      post_with_csrf delete_users_path, { user_ids: [@alice.id, @carol.id] }
    end

    assert_redirected_to users_path
    assert_not User.exists?(@alice.id)
    assert_not User.exists?(@carol.id)
  end

  test "an empty selection shows a message and changes nothing" do
    assert_no_difference "User.count" do
      post_with_csrf block_users_path, { user_ids: [] }
    end

    follow_redirect!
    assert_select ".alert-danger", text: /Select at least one user/i
  end

  # IMPORTANT: everybody may block or delete himself.
  test "a user can block himself" do
    post_with_csrf block_users_path, { user_ids: [@user.id] }

    assert_redirected_to users_path
    assert @user.reload.blocked?

    # NOTE: the next request of that user goes back to the login form.
    get users_path
    assert_redirected_to login_path
  end

  test "a user can delete himself" do
    assert_difference "User.count", -1 do
      post_with_csrf delete_users_path, { user_ids: [@user.id] }
    end

    assert_redirected_to login_path
  end

  test "the table shows the status and the timestamps" do
    get users_path

    # NOTE: the status is a text with a small dot (the reference of the task).
    assert_select "table#users-table tbody .status", 4

    assert_select "table#users-table tbody tr[data-user-id=?]", @alice.id do
      assert_select ".status-active", text: /Active/i
    end

    # NOTE: a blocked account is dimmed and its name is struck through.
    assert_select "table#users-table tbody tr.is-blocked[data-user-id=?]", @bob.id do
      assert_select ".status-blocked", text: /Blocked/i
    end

    # NOTE: the timestamps are relative, the exact time is in the tooltip.
    cells = css_select("table#users-table tbody td[title*='2026']")
    assert cells.any?
    assert(cells.all? { |cell| cell.text.match?(/ago|never/) })
  end

  # NOTE: the activity of an account is shown as a small bar chart under the
  # "last activity" column - one bar per day.
  test "the activity is shown as a small bar chart" do
    get users_path

    assert_select "table#users-table tbody tr[data-user-id=?]", @alice.id do
      assert_select ".activity-cell .sparkline .spark-bar", ActivityHistory::DAYS
    end
  end

  # NOTE: the designation below the name is "N/A" when the account has none.
  test "the designation of an account without a position shows N/A" do
    user = create_user(name: "Without Position")
    user.update_column(:position, nil)

    get users_path

    assert_select "table#users-table tbody tr[data-user-id=?]", user.id do
      assert_select ".cell-sub", text: "N/A"
    end
  end

  test "the filter of the table works" do    get users_path, params: { q: "alice" }

    assert_select "table#users-table tbody tr[data-user-id]", 1
    assert_select "table#users-table tbody tr[data-user-id=?]", @alice.id
  end

  test "the status filter of the table works" do
    get users_path, params: { status: "blocked" }

    assert_select "table#users-table tbody tr[data-user-id]", 1
    assert_select "table#users-table tbody tr[data-user-id=?]", @bob.id
  end

  # NOTE: no browser alert() is used anywhere - the messages are Bootstrap
  # alerts inside the page.
  test "the status messages are rendered inside the page" do
    post_with_csrf block_users_path, { user_ids: [@alice.id] }
    follow_redirect!

    assert_select ".alert-success", 1
    assert_select ".alert-success", text: /1 user blocked/i
  end
end

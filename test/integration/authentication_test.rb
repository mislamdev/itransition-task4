# frozen_string_literal: true

require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  # IMPORTANT: an unauthenticated visitor only sees the login form and the
  # registration form.
  test "an unauthenticated visitor is redirected from the user table to the login form" do
    get users_path

    assert_redirected_to login_path
    follow_redirect!
    assert_select "h1", text: /Sign in/i
  end

  test "the registration form is public" do
    get signup_path

    assert_response :success
    assert_select "form[action=?]", signup_path
  end

  test "the login form is public" do
    get login_path

    assert_response :success
    assert_select "form[action=?]", login_path
  end

  # NOTE: the registration is processed right away - the account exists
  # immediately and the message is shown.
  test "a user is registered right away" do
    assert_difference "User.count", 1 do
      post_with_csrf signup_path, { user: { name: "New User", email: "new@example.com", password: "a", password_confirmation: "a" } }
    end

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-success", text: /Registration successful/i
    assert User.exists?(email: "new@example.com")
  end

  test "a registration with a taken email shows an error" do
    create_user(email: "taken@example.com")

    assert_no_difference "User.count" do
      post_with_csrf signup_path, { user: { name: "Other", email: "taken@example.com", password: "a", password_confirmation: "a" } }
    end

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /already been taken/i
  end

  test "a user can sign in with a one character password" do
    user = create_user(email: "short@example.com", password: "a")

    sign_in(user, password: "a")

    assert_redirected_to users_path
    follow_redirect!
    assert_select ".alert-success", text: /Signed in/i
  end

  test "a wrong password shows an error message" do
    user = create_user(password: "a")

    sign_in(user, password: "wrong")

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /Invalid e-mail or password/i
  end

  test "a blocked user cannot sign in" do
    user = create_user(blocked: true)

    sign_in(user)

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /blocked/i
  end

  # IMPORTANT: the fifth requirement - the state of the account is checked on
  # EVERY request, not only when the user signs in.
  test "a blocked user is redirected to the login page on the next request" do
    user = create_user
    sign_in(user)
    assert_redirected_to users_path

    # NOTE: the administrator blocks the account in the meantime.
    user.update!(blocked: true)

    get users_path
    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-danger", text: /blocked/i
  end

  # IMPORTANT: the same for a deleted user - the session points to an account
  # that does not exist any more.
  test "a deleted user is redirected to the login page on the next request" do
    user = create_user
    sign_in(user)

    user.destroy!

    get users_path
    assert_redirected_to login_path
  end

  # NOTE: the status messages float in the top right corner and close
  # themselves after a few seconds.
  test "the status messages are toasts with a duration" do
    user = create_user
    sign_in(user)

    get users_path

    assert_select "div#flash-stack" do
      assert_select ".app-toast", 1
      assert_select ".app-toast[data-autohide]", 1
    end
  end

  test "an error message lives longer than a success message" do
    user = create_user(email: "blocked@example.com", blocked: true)

    post login_path, params: { email: user.email, password: "a", authenticity_token: csrf_token }

    assert_response :unprocessable_entity
    assert_select ".app-toast[data-autohide=?]", "10000", 1
  end

  test "a user can sign out" do
    user = create_user
    sign_in(user)

    delete logout_path, params: { authenticity_token: csrf_token }

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-success", text: /signed out/i
  end

  # NOTE: the sign out button lives inside the dropdown of the profile.
  test "the sign out button is inside the dropdown of the profile" do
    user = create_user
    sign_in(user)

    get users_path

    assert_select ".account-chip.dropdown-toggle", 1
    assert_select ".dropdown-menu .dropdown-item-danger", 1
    assert_select ".dropdown-menu form.dropdown-form button", 1
  end

  # NOTE: the "remember me" checkbox of the sign in form - the session of a
  # remembered account survives the restart of the browser.
  test "the session of a remembered account expires in 30 days" do
    user = create_user(email: "remembered@example.com")

    post login_path, params: { email: user.email, password: "a", remember_me: "1",
                               authenticity_token: csrf_token }

    assert_redirected_to users_path
    assert_equal 30.days.to_i, request.session_options[:expire_after].to_i
  end

  test "the session of a normal account ends with the browser" do
    user = create_user(email: "temporary@example.com")

    post login_path, params: { email: user.email, password: "a",
                               authenticity_token: csrf_token }

    assert_redirected_to users_path
    assert_nil request.session_options[:expire_after]
  end

  test "the assistant page is protected as well" do
    get assistant_path

    assert_redirected_to login_path
  end

  # IMPORTANT: a deleted user can register again - the row is really removed
  # from the table, therefore the e-mail is free again.
  test "a deleted user can register again" do
    user = create_user(email: "again@example.com")
    user.destroy!

    assert_difference "User.count", 1 do
      post_with_csrf signup_path, { user: { name: "Again", email: "again@example.com", password: "a", password_confirmation: "a" } }
    end

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-success", text: /Registration successful/i
  end

  # IMPORTANT: the blocked account cannot sign in, but the account still exists.
  test "a blocked account is still in the database" do
    user = create_user(email: "blocked@example.com", blocked: true)

    assert User.exists?(user.id)
    assert User.find(user.id).blocked?
  end
end

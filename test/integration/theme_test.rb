# frozen_string_literal: true

require "test_helper"

class ThemeTest < ActionDispatch::IntegrationTest
  # NOTE: the switch of the theme is a form - the server stores the choice in
  # a cookie and renders the page in the chosen theme.
  test "the theme is switched on and stored in a cookie" do
    post_with_csrf theme_path, { theme: "dark" }

    assert_response :redirect
    assert_equal "dark", cookies[ThemesController::COOKIE_NAME]
  end

  # IMPORTANT: the switch works without a session as well - the sign in page
  # has the button too.
  test "the theme can be switched without a session" do
    get login_path
    assert_select ".theme-toggle", 1

    post_with_csrf theme_path, { theme: "dark" }
    assert_response :redirect
  end

  # IMPORTANT: the server renders the page in the chosen theme - therefore
  # there is no flash of the light theme while the page loads.
  test "the page is rendered in the dark theme when the cookie is set" do
    cookies[ThemesController::COOKIE_NAME] = "dark"

    get login_path

    assert_select "html.theme-dark", 1
    assert_match(/data-bs-theme="dark"/, response.body)
  end

  test "the page is rendered in the light theme by default" do
    get login_path

    assert_select "html.theme-dark", 0
    assert_match(/data-bs-theme="light"/, response.body)
  end

  test "the theme of the signed in application is switched as well" do
    user = create_user
    sign_in(user)

    post_with_csrf theme_path, { theme: "dark" }
    assert_equal "dark", cookies[ThemesController::COOKIE_NAME]

    get users_path
    assert_select "html.theme-dark", 1
  end

  # NOTE: an unknown value falls back to the light theme.
  test "an unknown theme falls back to the light theme" do
    post_with_csrf theme_path, { theme: "neon" }

    assert_equal "light", cookies[ThemesController::COOKIE_NAME]
  end
end

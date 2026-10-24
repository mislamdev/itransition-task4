# frozen_string_literal: true

# The switch between the light and the dark theme.
#
# IMPORTANT: the choice is stored in a cookie and the SERVER renders the page
# in the chosen theme - therefore there is no flash of the wrong theme while
# the page loads (a solution with localStorage would paint the light theme
# first and switch it afterwards).
class ThemesController < ApplicationController
  # NOTE: the name of the cookie with the theme.
  COOKIE_NAME = "user_management_theme".freeze

  # NOTE: POST /theme - switches the theme and comes back to the page.
  def update
    theme = params[:theme].to_s == "dark" ? "dark" : "light"

    cookies[COOKIE_NAME] = {
      value: theme,
      expires: 1.year.from_now,
      httponly: true,
      same_site: :lax,
      secure: request.ssl?
    }

    redirect_back fallback_location: root_path, notice: theme_message(theme)
  end

  private

  # Small function: the message of the switch.
  def theme_message(theme)
    theme == "dark" ? "The dark theme is switched on." : "The light theme is switched on."
  end
end

# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # NOTE: the CSRF protection of the browser forms. The JSON API skips it for
  # the service calls that carry the API token (see Api::V1::BaseController) -
  # those requests do not use the cookies of the browser at all.
  protect_from_forgery with: :exception, unless: :skip_csrf_check?

  # ---------------------------------------------------------------------------
  # THE FIFTH REQUIREMENT
  #
  # "BEFORE EACH REQUEST EXCEPT FOR REGISTRATION OR LOGIN, SERVER SHOULD CHECK
  #  IF USER EXISTS AND ISN'T BLOCKED (if user account is blocked or deleted, any
  #  next user's request should redirect to the login page)."
  #
  # The check below runs before EVERY action of every controller, except the
  # registration / login actions which are listed in PUBLIC_ACTIONS.
  #
  # IMPORTANT: `current_user` is re-read from the DATABASE on every request
  # (no caching between requests), therefore blocking or deleting a user takes
  # effect on the very next request of that user - even in another browser tab.
  # ---------------------------------------------------------------------------
  before_action :require_authenticated_user

  helper_method :current_user, :signed_in?, :page_title, :current_theme, :dark_theme?

  # NOTE: these actions are the only ones that may be reached without a
  # session. Everything else requires an existing, non-blocked account.
  #
  # IMPORTANT: the switch of the theme is public as well - the sign in page
  # has the button too.
  PUBLIC_ACTIONS = %w[
    sessions#new sessions#create
    registrations#new registrations#create
    themes#update
  ].freeze

  private

  # Small function: returns the User object of the current session or nil.
  # NOTE: the database is hit on every call - that is exactly what we need, see
  # the IMPORTANT note in the class comment above.
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  # Small function: convenience predicate for the views.
  def signed_in?
    current_user.present?
  end

  # The authentication filter. Small function, very important behaviour.
  def require_authenticated_user
    return if public_action?

    user = current_user

    # NOTE: no user at all -> back to the login form.
    if user.nil?
      reset_session
      authentication_failure("Please sign in to continue.")
      return
    end

    # NOTE: the account was BLOCKED by an administrator -> back to the login form.
    if user.blocked?
      reset_session
      authentication_failure("Your account is blocked. Please contact an administrator.")
      return
    end

    # NOTE: the account still exists (it was not deleted) -> remember the activity.
    touch_activity(user)
  end

  # Small function: what happens when the check fails.
  # IMPORTANT: the JSON API replaces this method and answers with 401 instead
  # of a redirect (a machine client cannot follow a redirect to a login form).
  def authentication_failure(message)
    redirect_to login_path, alert: message
  end

  # Small function: true for the actions that are allowed without a session.
  def public_action?
    PUBLIC_ACTIONS.include?("#{controller_path}##{action_name}")
  end

  # Small function: the CSRF check is only skipped for the service calls of
  # the JSON API - a browser request always has to send the token.
  def skip_csrf_check?
    false
  end

  # Small function: updates "last activity" once per request.
  # NOTA BENE: this is what makes the "Last activity" column of the admin table
  # meaningful - it shows that the account was really used, not only signed in.
  def touch_activity(user)
    # NOTE: update_columns is used on purpose: no validations, no callbacks and
    # therefore no risk of raising an exception in the middle of a request.
    user.update_columns(last_activity_at: Time.current, updated_at: Time.current)

    # NOTE: the activity is also written into the history - it is the source of
    # the small bar chart under the "last activity" column.
    UserActivity.record(user)
  end

  # Small function: the title shown in the browser tab and in the navigation bar.
  def page_title
    "User Management"
  end

  # Small function: the theme of the page - "light" or "dark".
  #
  # IMPORTANT: the theme is read from the cookie, therefore the server renders
  # the page in the chosen theme (no flash of the wrong theme).
  def current_theme
    @current_theme ||= cookies[ThemesController::COOKIE_NAME].to_s == "dark" ? "dark" : "light"
  end

  # Small function: the dark theme is switched on.
  def dark_theme?
    current_theme == "dark"
  end
end

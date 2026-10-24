# frozen_string_literal: true

# Handles the sign in form.
class SessionsController < ApplicationController
  # NOTE: the sign in and the registration use their own layout - the split
  # screen of the reference design.
  layout "auth"

  # NOTE: how long a "remembered" session lives.
  REMEMBER_PERIOD = 30.days

  # NOTE: GET /login - the sign in form.
  def new
    # IMPORTANT: an already authenticated (and not blocked) user has no reason
    # to see the login form again - send them to the admin table instead.
    if signed_in?
      redirect_to users_path
      return
    end

    @email = ""
  end

  # NOTE: POST /login - checks the credentials and opens the session.
  def create
    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s
    user = User.find_by(email: email)

    if user.nil?
      # NOTE: generic message - we do not tell a stranger whether the e-mail is
      # registered at all.
      flash.now[:alert] = "Invalid e-mail or password."
      @email = email
      render :new, status: :unprocessable_entity
      return
    end

    # IMPORTANT: a blocked user must not be able to sign in.
    if user.blocked?
      flash.now[:alert] = "This account is blocked. Please contact an administrator."
      @email = email
      render :new, status: :unprocessable_entity
      return
    end

    if user.authenticate(password)
      # NOTE: session fixation protection - a brand new session id is issued.
      reset_session

      # IMPORTANT: the "remember me" checkbox decides how long the session
      # cookie lives - a remembered account survives the restart of the
      # browser.
      if params[:remember_me] == "1"
        request.session_options[:expire_after] = REMEMBER_PERIOD
      end

      session[:user_id] = user.id
      user.record_login!
      redirect_to users_path, notice: "Signed in as #{user.email}."
    else
      flash.now[:alert] = "Invalid e-mail or password."
      @email = email
      render :new, status: :unprocessable_entity
    end
  end

  # NOTE: DELETE (or POST) /logout - closes the session.
  def destroy
    reset_session
    redirect_to login_path, notice: "You have been signed out."
  end
end

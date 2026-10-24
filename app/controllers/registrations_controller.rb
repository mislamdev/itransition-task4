# frozen_string_literal: true

# Handles the registration form.
#
# IMPORTANT: "Users are registered right away" - the account is created
# immediately, it is NOT waiting for an approval and it is NOT blocked.
class RegistrationsController < ApplicationController
  # NOTE: the registration uses the same layout as the sign in.
  layout "auth"

  # NOTE: GET /signup - the registration form.
  def new
    if signed_in?
      redirect_to users_path
      return
    end

    @user = User.new
  end

  # NOTE: POST /signup - creates the account.
  def create
    @user = User.new(user_params)

    if @user.save
      # NOTE: the account exists right now and can be used to sign in.
      redirect_to login_path, notice: "Registration successful. You can sign in now."
    else
      # NOTE: the error messages are rendered next to the fields.
      flash.now[:alert] = "Registration failed. Please correct the errors below."
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # IMPORTANT: this branch can only be reached when two registrations with the
    # same e-mail happen at exactly the same time. The UNIQUE INDEX in the
    # database rejected the second row - that is the guarantee the task asks
    # for. We simply turn the database error into a friendly message.
    @user = User.new(user_params)
    @user.errors.add(:email, "has already been taken")
    flash.now[:alert] = "Registration failed. Please correct the errors below."
    render :new, status: :unprocessable_entity
  end

  private

  # Small function: the list of permitted parameters (strong parameters).
  # NOTA BENE: `blocked`, `last_login_at` and friends are NOT permitted - a
  # visitor can never make himself an administrator or fake a login time.
  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end

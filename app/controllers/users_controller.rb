# frozen_string_literal: true

# The admin panel: the user management table with the toolbar above it.
#
# IMPORTANT: this controller NEVER renders a button inside a table row. All the
# actions live in the toolbar and are executed on the selected rows.
class UsersController < ApplicationController
  # NOTE: the columns the table may be sorted by.
  SORTABLE_COLUMNS = {
    "name" => "users.name",
    "email" => "users.email",
    "position" => "users.position",
    "last_login_at" => "users.last_login_at",
    "last_activity_at" => "users.last_activity_at",
    "status" => "users.blocked",
    "created_at" => "users.created_at"
  }.freeze

  # NOTE: GET /users - the admin table.
  def index
    @sort_column = params[:sort].presence_in(SORTABLE_COLUMNS.keys) || "last_login_at"
    @sort_direction = params[:direction] == "asc" ? "asc" : "desc"
    @status_filter = params[:status].presence_in(%w[active blocked all]) || "all"
    @query = params[:q].to_s.strip

    scope = filtered_scope
    @total_count = scope.count
    @blocked_count = scope.blocked.count
    @active_count = scope.active.count

    # IMPORTANT: the data in the table is ALWAYS sorted (the task requires it).
    # The default order is "last login time, the most recent first".
    @users = scope.order(order_clause).to_a

    # NOTE: the ids of the rows that are currently selected in the browser.
    # They are used to enable / disable the toolbar buttons.
    @selected_ids = Array(params[:selected_ids]).filter_map { |id| Integer(id, exception: false) }
  end

  # NOTE: POST /users/block_users - the "Block" button of the toolbar.
  def block_users
    ids = selected_ids
    if ids.empty?
      redirect_to users_path, alert: "Select at least one user first."
      return
    end

    count = User.where(id: ids).update_all(blocked: true, updated_at: Time.current)
    redirect_to users_path, notice: "#{count} #{count == 1 ? 'user' : 'users'} blocked."
  end

  # NOTE: POST /users/unblock_users - the "Unblock" icon of the toolbar.
  def unblock_users
    ids = selected_ids
    if ids.empty?
      redirect_to users_path, alert: "Select at least one user first."
      return
    end

    count = User.where(id: ids).update_all(blocked: false, updated_at: Time.current)
    redirect_to users_path, notice: "#{count} #{count == 1 ? 'user' : 'users'} unblocked."
  end

  # NOTE: POST /users/delete_users - the "Delete" icon of the toolbar.
  def delete_users
    ids = selected_ids
    if ids.empty?
      redirect_to users_path, alert: "Select at least one user first."
      return
    end

    deleted_count = 0
    self_deleted = false

    # IMPORTANT: the rows are physically REMOVED from the database, they are not
    # flagged with a "deleted" flag.
    User.where(id: ids).find_each do |user|
      self_deleted = true if user.id == current_user&.id
      user.destroy!
      deleted_count += 1
    end

    if self_deleted
      # NOTE: the user removed his own account - the session points to a user
      # that does not exist any more, so we close it and send him to the login
      # form (this is exactly the behaviour required by the FIFTH REQUIREMENT).
      reset_session
      redirect_to login_path, notice: "Your account has been deleted."
    else
      redirect_to users_path, notice: "#{deleted_count} #{deleted_count == 1 ? 'user' : 'users'} deleted."
    end
  end

  private

  # Small function: builds the SQL scope from the filter controls.
  def filtered_scope
    scope = User.all
    scope = scope.active  if @status_filter == "active"
    scope = scope.blocked if @status_filter == "blocked"

    if @query.present?
      # NOTE: SQL LIKE with escaped wildcards - the search term is never
      # interpolated into raw SQL, it is passed as a bind parameter.
      pattern = "%#{User.sanitize_sql_like(@query.downcase)}%"
      scope = scope.where("LOWER(users.name) LIKE :pattern OR LOWER(users.email) LIKE :pattern", pattern: pattern)
    end

    scope
  end

  # Small function: the ORDER BY clause for the current sort selection.
  # NOTA BENE: the column name comes from a whitelist (SORTABLE_COLUMNS), so it
  # can never be injected by a user.
  def order_clause
    column = SORTABLE_COLUMNS.fetch(@sort_column)
    direction = @sort_direction == "asc" ? "ASC" : "DESC"

    if @sort_column == "status"
      # NOTE: sorting by status = sorting by the `blocked` flag.
      "users.blocked #{direction}, users.email ASC"
    elsif @sort_column == "last_login_at" || @sort_column == "last_activity_at"
      # IMPORTANT: users that never logged in go to the bottom, no matter which
      # direction is chosen.
      "#{column} #{direction} NULLS LAST, users.email ASC"
    else
      "#{column} #{direction}, users.email ASC"
    end
  end

  # Small function: the ids of the selected rows, cleaned up.
  # IMPORTANT: only integers are kept, so a crafted form cannot inject anything.
  def selected_ids
    Array(params[:user_ids]).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
  end
end

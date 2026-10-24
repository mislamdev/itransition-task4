# frozen_string_literal: true

# The bulk operations behind the toolbar buttons (Block / Unblock / Delete).
#
# IMPORTANT: the HTML controller (app/controllers/users_controller.rb) and the
# JSON API (app/controllers/api/v1/users_controller.rb) both call this service,
# so the behaviour is identical no matter how the operation was triggered.
class UserBulkAction
  # NOTE: the operations the toolbar offers.
  OPERATIONS = %w[block unblock delete].freeze

  # Small function: performs the operation on the given ids.
  #
  # NOTA BENE: `delete` really removes the rows from the table - the task says
  # "Deleted users should be deleted, not marked".
  def self.call(operation, ids)
    operation = operation.to_s.downcase
    raise ArgumentError, "unknown operation: #{operation}" unless OPERATIONS.include?(operation)

    ids = Array(ids).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
    return { "operation" => operation, "count" => 0, "ids" => [] } if ids.empty?

    case operation
    when "block"
      count = User.where(id: ids).update_all(blocked: true, updated_at: Time.current)
      { "operation" => operation, "count" => count, "ids" => ids }
    when "unblock"
      count = User.where(id: ids).update_all(blocked: false, updated_at: Time.current)
      { "operation" => operation, "count" => count, "ids" => ids }
    when "delete"
      # IMPORTANT: destroy_all removes the rows physically - it is NOT a soft
      # delete (the task asks for a real deletion). The history of the activity
      # belongs to the account and is deleted with it.
      target = User.where(id: ids)
      count = target.count
      target.destroy_all
      { "operation" => operation, "count" => count, "ids" => ids }
    end
  end
end

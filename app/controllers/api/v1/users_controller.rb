# frozen_string_literal: true

module Api
  module V1
    # The query API for the users.
    #
    # IMPORTANT: this is the API the assistant calls. Every number in the
    # answer of the assistant comes from here - the database counts, not the
    # language model.
    class UsersController < BaseController
      # NOTE: GET /api/v1/users - the list of users with the applied filters.
      def index
        query = UserQuery.new(query_params)
        scope = query.scope

        total = scope.count
        users = scope.order(query.order_clause).limit(query.limit).offset(query.offset).to_a

        render json: {
          "query" => query.filters,
          "total_count" => total,
          "returned_count" => users.size,
          "users" => users.map { |user| UserQuery.serialize(user) }
        }
      end

      # NOTE: GET /api/v1/users/stats - all the counters in one call.
      def stats
        render json: UserQuery.new(query_params).statistics
      end

      # NOTE: POST /api/v1/users/bulk_block - the toolbar action (JSON flavour).
      def bulk_block
        render json: UserBulkAction.call("block", params[:user_ids])
      end

      # NOTE: POST /api/v1/users/bulk_unblock - the toolbar action (JSON flavour).
      def bulk_unblock
        render json: UserBulkAction.call("unblock", params[:user_ids])
      end

      # NOTE: POST /api/v1/users/bulk_delete - the toolbar action (JSON flavour).
      def bulk_delete
        render json: UserBulkAction.call("delete", params[:user_ids])
      end

      private

      # Small function: the parameters of the query - a strict whitelist.
      # IMPORTANT: only these parameters are accepted, everything else is
      # ignored, so no unknown column can ever reach the database.
      def query_params
        params.permit(
          :q, :email_prefix, :email_prefixes, :email_contains, :name_contains,
          :domain, :status, :window, :group_by, :sort, :direction, :limit, :offset
        )
      end
    end
  end
end

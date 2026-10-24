# frozen_string_literal: true

module Api
  module V1
    # The base class of the JSON API.
    #
    # IMPORTANT: the API is protected exactly like the web interface:
    #  - a browser session (cookie) is accepted,
    #  - a service token (Authorization: Bearer ...) is accepted, this is how
    #    the assistant itself calls the API.
    class BaseController < ApplicationController
      # NOTE: the API answers with JSON - a redirect to the login page would
      # be useless for a machine client.
      def authentication_failure(message)
        render json: { "error" => message }, status: :unauthorized
      end

      private

      # Small function: a service token replaces the session for server to
      # server calls. IMPORTANT: it is derived from the secret_key_base of the
      # environment, so it is different in every environment.
      def require_authenticated_user
        return if valid_service_token?

        super
      end

      # Small function: requests without cookies do not need a CSRF token.
      # NOTA BENE: only requests that carry the service token are treated that
      # way - browser requests still have to send the CSRF token.
      def skip_csrf_check?
        valid_service_token?
      end

      # Small function: the token of the request (if any).
      def request_token
        @request_token ||= begin
          header = request.authorization.to_s
          bearer = header[/\ABearer\s+(.+)\z/i, 1]
          bearer || request.headers["X-Api-Token"].presence
        end
      end

      # Small function: constant time comparison of the token.
      def valid_service_token?
        return false if request_token.blank?

        ActiveSupport::SecurityUtils.secure_compare(request_token.to_s, Assistant.api_token)
      end
    end
  end
end

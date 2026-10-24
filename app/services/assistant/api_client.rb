# frozen_string_literal: true

require "net/http"
require "json"

module Assistant
  # A tiny HTTP client for the REST API of this application.
  #
  # IMPORTANT: the assistant does NOT read the database directly. It asks the
  # API, exactly like any other (external) client would do. That is what makes
  # the API a real, reusable contract - and it is what guarantees that the
  # assistant answers with the numbers PostgreSQL computed.
  class ApiClient
    # NOTE: one executed call - the result is shown in the UI so that the user
    # can see which API produced the answer.
    Call = Struct.new(:method, :path, :params, :status, :body, :error, keyword_init: true) do
      def ok?
        status.to_i.between?(200, 299)
      end

      def to_h
        { "method" => method, "path" => path, "params" => params, "status" => status }
      end
    end

    def initialize(base_url: Assistant.base_url, token: Assistant.api_token, open_timeout: 5, read_timeout: 15)
      @base_url = base_url.to_s.chomp("/")
      @token = token
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # Small function: GET request with query parameters.
    def get(path, params = {})
      return offline_call("GET", path, params) unless online?

      uri = URI.parse("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params.compact) if params.present?

      request = Net::HTTP::Get.new(uri)
      apply_headers(request)

      perform(request, uri, "GET", path, params)
    end

    # Small function: POST request with a JSON body.
    def post(path, payload = {})
      return offline_call("POST", path, payload) unless online?

      uri = URI.parse("#{@base_url}#{path}")

      request = Net::HTTP::Post.new(uri)
      apply_headers(request)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      perform(request, uri, "POST", path, payload)
    end

    private

    # Small function: is the API reachable over HTTP?
    #
    # IMPORTANT: in the TEST environment the assistant works in-process. The
    # tests must never depend on a running server (and they must never touch
    # the data of the development database).
    def online?
      return false if Rails.env.test?

      true
    end

    # Small function: the answer of an offline call - the caller uses the
    # in-process implementation instead.
    def offline_call(method, path, params)
      Call.new(method: method, path: path, params: params, status: 0, body: {},
               error: "the API is called in-process (test environment)")
    end

    # Small function: the shared headers (the service token authenticates the
    # assistant as a service, not as a browser session).
    def apply_headers(request)
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{@token}" if @token.present?
    end

    # Small function: performs the request and parses the JSON answer.
    # NOTA BENE: any network problem is captured in the Call object instead of
    # raising - the caller decides what to do with it.
    def perform(request, uri, method, path, params)
      response = Net::HTTP.start(uri.hostname, uri.port,
                                  use_ssl: uri.scheme == "https",
                                  open_timeout: @open_timeout,
                                  read_timeout: @read_timeout) do |http|
        http.request(request)
      end

      status = response.code.to_i
      content_type = response["content-type"].to_s

      # IMPORTANT: a redirect or an HTML page is NOT an answer of the API. Such
      # a response is treated as a failure, so that the caller can fall back to
      # the in-process implementation instead of showing wrong numbers.
      if status >= 300 || status < 200 || !content_type.include?("json")
        return Call.new(method: method, path: path, params: params, status: 0, body: {},
                        error: "the API answered with #{status} (#{content_type.presence || 'no content type'})")
      end

      body = begin
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        { "raw" => response.body.to_s }
      end

      Call.new(method: method, path: path, params: params, status: status, body: body)
    rescue StandardError => e
      # NOTE: the error text is kept, it is shown as a status message.
      Call.new(method: method, path: path, params: params, status: 0, body: {}, error: e.message)
    end
  end
end

# frozen_string_literal: true

require "net/http"
require "json"

module Assistant
  # The optional translator that uses a large language model.
  #
  # IMPORTANT: the model is ONLY allowed to translate the sentence into a plan.
  # It never sees the user table and it never produces the answer - the answer
  # is always assembled from the numbers the REST API returned. That is the
  # difference between "an AI that counts" and "an AI that asks a database".
  class LlmPlanner
    SYSTEM_PROMPT = <<~PROMPT
      You translate a question or a command about a user management application
      into a JSON "plan". You never answer the question yourself and you never
      invent numbers - the plan is executed against the real database.

      The application manages users with: name, e-mail, status (active/blocked),
      last login time, last activity time and registration date.

      Intent rules:
      - count_users: the question asks for a number of users (total, per status,
        per time window, per e-mail prefix...).
      - list_users: the question asks for the users themselves.
      - user_stats: the question asks for a breakdown (by status, by domain).
      - user_detail: the question asks about one specific user.
      - select_users / clear_selection / block_users / unblock_users /
        delete_users / set_filter / sort_by / refresh_table: the sentence is a
        command that must be executed on the dashboard.
      - unknown: nothing matches.

      Filters:
      - status: "active", "blocked" or "all".
      - email_prefixes: e.g. ["s", "p"] for "e-mails started with s or p".
      - email_contains / name_contains / domain: the corresponding fragment.
      - q: an e-mail or a name the user mentioned explicitly.
      - window: "day" for today, "week" for the last 7 days, "month" for the
        last 30 days, otherwise "all".
      Never_logged_in is true for "users who never logged in".
      Metric is "registration" for a question about the registration date
      ("how many users registered this week") and "login" for a question about
      the login time ("how many users logged in this week").
    PROMPT

    def initialize(text)
      @text = text.to_s
    end

    # Small function: asks the model for a plan.
    def plan
      raw = case Assistant.llm_provider
            when "anthropic" then call_anthropic
            else call_openai
            end
      PlanSchema.normalize(raw)
    end

    private

    # Small function: OpenAI compatible chat completion with structured output.
    def call_openai
      uri = URI.parse("#{Assistant.llm_base_url}/chat/completions")
      payload = {
        model: Assistant.llm_model,
        temperature: 0,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: @text }
        ],
        response_format: {
          type: "json_schema",
          json_schema: { name: "query_plan", strict: true, schema: PlanSchema.json_schema }
        }
      }

      response = post_json(uri, payload)
      content = response.dig("choices", 0, "message", "content")
      parse_json(content)
    end

    # Small function: Anthropic messages API with a forced tool call.
    def call_anthropic
      uri = URI.parse("#{Assistant.llm_base_url}/v1/messages")
      payload = {
        model: Assistant.llm_model,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        tools: [
          { name: "query_plan", description: "The structured plan for the user request.",
            input_schema: PlanSchema.json_schema }
        ],
        tool_choice: { type: "tool", name: "query_plan" },
        messages: [{ role: "user", content: @text }]
      }

      response = post_json(uri, payload)
      block = Array(response["content"]).find { |part| part["type"] == "tool_use" }
      block && block["input"]
    end

    # Small function: POST with the shared headers.
    def post_json(uri, payload)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{ENV['LLM_API_KEY']}"
      # NOTE: Anthropic uses its own header name.
      request["x-api-key"] = ENV["LLM_API_KEY"] if Assistant.llm_provider == "anthropic"
      request["anthropic-version"] = "2023-06-01" if Assistant.llm_provider == "anthropic"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.hostname, uri.port,
                                 use_ssl: uri.scheme == "https",
                                 open_timeout: 10, read_timeout: 30) { |http| http.request(request) }

      JSON.parse(response.body.to_s)
    rescue StandardError
      # IMPORTANT: a failing model must never break the application - the
      # executor falls back to the deterministic planner.
      {}
    end

    # Small function: the content of the model is JSON - but never trust it.
    def parse_json(content)
      return {} if content.blank?

      JSON.parse(content)
    rescue JSON::ParserError
      {}
    end
  end
end

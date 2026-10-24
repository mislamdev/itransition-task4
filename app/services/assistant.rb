# frozen_string_literal: true

module Assistant
  # Configuration of the assistant module.
  module_function

  # IMPORTANT: the address of the application itself. The assistant calls the
  # REST API of this very application over HTTP, exactly like any other client
  # would do - that is what makes the API a real contract instead of a helper
  # method.
  # NOTE: the port can be changed with the environment variable
  # ASSISTANT_API_BASE_URL (or PORT).
  def base_url
    ENV.fetch("ASSISTANT_API_BASE_URL", "http://127.0.0.1:#{ENV.fetch('PORT', 3100)}")
  end

  # NOTE: the shared secret for service-to-service calls.
  # IMPORTANT: it is derived from the secret_key_base of the environment, so it
  # is different for development, test and production and it never has to be
  # copied around.
  def api_token
    @api_token ||= OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base.to_s,
      "user-management-api-token"
    )
  end

  # NOTE: which planner is used to understand the natural language.
  #
  #  - "llm"  : a large language model translates the question into a plan.
  #  - "rules" : a deterministic grammar (no network, no key, always available).
  #
  # IMPORTANT: both planners produce the SAME structured plan, and the numbers
  # in the answer always come from the database - never from the model.
  def planner_engine
    engine = ENV.fetch("ASSISTANT_ENGINE", "").downcase
    return engine if %w[llm rules auto].include?(engine)

    llm_available? ? "llm" : "rules"
  end

  def llm_available?
    return false if ENV["LLM_API_KEY"].blank?

    %w[openai anthropic].include?(llm_provider)
  end

  def llm_provider
    ENV.fetch("LLM_PROVIDER", "openai").downcase
  end

  def llm_model
    ENV.fetch("LLM_MODEL", llm_provider == "anthropic" ? "claude-3-5-haiku-latest" : "gpt-4o-mini")
  end

  def llm_base_url
    ENV.fetch("LLM_BASE_URL", llm_provider == "anthropic" ? "https://api.anthropic.com" : "https://api.openai.com/v1")
  end
end

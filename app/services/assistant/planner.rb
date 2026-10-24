# frozen_string_literal: true

module Assistant
  # Chooses the planner that understands the natural language.
  #
  # IMPORTANT: the deterministic grammar is the default, because it works
  # without a key and without a network. If LLM_API_KEY is configured the model
  # is used first - and if the model fails, the grammar takes over.
  class Planner
    def initialize(text)
      @text = text.to_s
    end

    # Small function: returns { "plan" => ..., "engine" => "rules" | "llm" }.
    def call
      engine = Assistant.planner_engine

      if engine == "llm"
        plan = LlmPlanner.new(@text).plan
        # NOTE: an empty / unknown plan from the model is not good enough ->
        # the deterministic planner gets a second chance.
        return { "plan" => plan, "engine" => "llm" } if plan["intent"] != "unknown"

        return { "plan" => RulePlanner.new(@text).plan, "engine" => "rules (llm fallback)" }
      end

      { "plan" => RulePlanner.new(@text).plan, "engine" => "rules" }
    end
  end
end

# frozen_string_literal: true

# The HTML page with the assistant (natural language questions + commands).
class AssistantController < ApplicationController
  # NOTE: GET /assistant
  def index
    @questions = AssistantSuggestions::QUESTIONS
  end
end

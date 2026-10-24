# frozen_string_literal: true

module Api
  module V1
    # The API of the assistant.
    #
    # IMPORTANT: two different jobs, one endpoint family:
    #  - /api/v1/assistant/ask      -> a question about the data, answered with text
    #  - /api/v1/assistant/command  -> a command that controls the dashboard
    class AssistantController < BaseController
      # NOTE: POST /api/v1/assistant/ask
      # Body: { "question": "how many users are blocked?" }
      def ask
        question = params[:question].to_s.strip
        if question.blank?
          render json: { "error" => "The question must not be empty." }, status: :unprocessable_entity
          return
        end

        render json: Assistant::Executor.new(text: question, selected_ids: selected_ids).call
      end

      # NOTE: POST /api/v1/assistant/command
      # Body: { "command": "select users with e-mails started with s or p",
      #          "selected_ids": [1, 2] }
      def command
        command = params[:command].to_s.strip
        if command.blank?
          render json: { "error" => "The command must not be empty." }, status: :unprocessable_entity
          return
        end

        render json: Assistant::Executor.new(text: command, selected_ids: selected_ids).call
      end

      private

      # Small function: the ids that are ticked in the browser.
      def selected_ids
        Array(params[:selected_ids]).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
      end
    end
  end
end

# frozen_string_literal: true

# The example questions that are offered in the assistant UI.
#
# IMPORTANT: they show what the assistant can do - they are NOT hard coded
# answers, every one of them is really executed against the API.
module AssistantSuggestions
  QUESTIONS = [
    "How many users are there in total?",
    "How many users are blocked?",
    "How many users logged in during the last 7 days?",
    "How many users have never logged in?",
    "How many active users are there?",
    "Show the users whose e-mail starts with s",
    "How many users registered this week?",
    "List the blocked users",
    "How many users are there per e-mail domain?"
  ].freeze

  # NOTE: the example commands of the dashboard assistant.
  COMMANDS = [
    "Select users with e-mails started with s or p",
    "Select the blocked users",
    "Block the selected users",
    "Unblock the selected users",
    "Delete the selected users",
    "Clear the selection",
    "Sort by e-mail",
    "Show only blocked users"
  ].freeze
end

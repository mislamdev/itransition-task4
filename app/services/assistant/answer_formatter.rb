# frozen_string_literal: true

module Assistant
  # Builds the TEXT of the answer.
  #
  # IMPORTANT: every number in the text is taken from the API payload - nothing
  # is calculated, rounded or guessed here. That is how the assistant avoids
  # hallucinating numbers.
  class AnswerFormatter
    # NOTE: the time windows of the plan and the counters of the API.
    ACTIVITY_KEYS = {
      "day" => "last_login_24h",
      "week" => "last_login_7d",
      "month" => "last_login_30d"
    }.freeze

    # NOTE: the same windows for the registration date.
    REGISTRATION_KEYS = {
      "day" => "registered_24h",
      "week" => "registered_7d",
      "month" => "registered_30d"
    }.freeze

    def initialize(intent:, plan:, payload: {}, extra: {})
      @intent = intent.to_s
      @plan = plan || {}
      @payload = payload || {}
      @extra = extra || {}
    end

    # Small function: the final text.
    def call
      case @intent
      when "count_users" then count_text
      when "list_users" then list_text
      when "user_stats" then stats_text
      when "user_detail" then detail_text
      when "select_users" then "Selected #{@extra['count'].to_i} #{plural(@extra['count'], 'user')}. " \
                               "The checkboxes in the table are now ticked."
      when "clear_selection" then "Selection cleared."
      when "block_users" then "Blocked #{@extra['count'].to_i} #{plural(@extra['count'], 'user')}."
      when "unblock_users" then "Unblocked #{@extra['count'].to_i} #{plural(@extra['count'], 'user')}."
      when "delete_users" then "Deleted #{@extra['count'].to_i} #{plural(@extra['count'], 'user')}. " \
                               "The rows were removed from the database."
      when "set_filter" then "The table filter was updated."
      when "sort_by" then "The table is now sorted by #{@plan['sort'].to_s.humanize.downcase} " \
                         "(#{@plan['direction'] == 'asc' ? 'ascending' : 'descending'})."
      when "refresh_table" then "The table was refreshed."
      else "I did not understand that request. Try: \"how many users are blocked\", " \
           "\"show users whose e-mail starts with s\", \"select users with e-mails started with s or p\"."
      end
    end

    private

    # Small function: the answer for a counting question.
    def count_text
      totals = @payload["totals"] || {}
      overall = @payload["overall"] || {}
      activity = @payload["activity"] || {}
      # IMPORTANT: "in total" always means the whole table, not the filtered
      # part of it.
      total = (overall["users"] || totals["users"]).to_i

      # IMPORTANT: when the question asked for a breakdown ("per domain"), the
      # groups of the API are the answer.
      return stats_text if @plan["group_by"].to_s != "none" && @payload["groups"].present?

      if @plan["never_logged_in"]
        count = activity["never_logged_in"].to_i
        return "#{count} #{plural(count, 'user has', 'users have')} never logged in (#{total} #{plural(total, 'user')} in total)."
      end

      window = @plan.dig("filters", "window").to_s
      if window != "all"
        registration = @plan["metric"].to_s == "registration"
        key = registration ? REGISTRATION_KEYS.fetch(window, "registered_7d") : ACTIVITY_KEYS.fetch(window, "last_login_7d")
        count = activity.fetch(key, 0).to_i
        verb = registration ? "registered" : "logged in"
        return "#{count} #{plural(count, 'user', 'users')} #{verb} during the last #{window_word(window)} " \
               "(#{total} #{plural(total, 'user')} in total)."
      end

      scope = scope_description(include_status: false)
      if @plan.dig("filters", "status") == "blocked"
        "#{totals['blocked'].to_i} blocked #{plural(totals['blocked'].to_i, 'user')} #{scope} " \
          "(#{total} #{plural(total, 'user')} in total)."
      elsif @plan.dig("filters", "status") == "active"
        "#{totals['active'].to_i} active #{plural(totals['active'].to_i, 'user')} #{scope} " \
          "(#{total} #{plural(total, 'user')} in total)."
      else
        "There are #{total} #{plural(total, 'user')} #{scope}: #{totals['active'].to_i} active and " \
          "#{totals['blocked'].to_i} blocked."
      end
    end

    # Small function: the answer for "show me the users ...".
    def list_text
      users = @payload["users"] || []
      total = @payload["total_count"].to_i

      if users.empty?
        return "No user matches #{scope_description}."
      end

      preview = users.first(10).map { |user| user["email"] }
      text = "Found #{total} #{plural(total, 'user')} #{scope_description}: #{preview.join(', ')}"
      text += " ... (showing the first #{users.size} of #{total})" if total > users.size
      text + "."
    end

    # Small function: the answer for a breakdown question.
    def stats_text
      totals = @payload["totals"] || {}
      groups = @payload["groups"] || []

      if groups.empty?
        return "There are #{totals['users'].to_i} users: #{totals['active'].to_i} active and #{totals['blocked'].to_i} blocked."
      end

      lines = groups.map { |group| "#{group['key']}: #{group['count'].to_i}" }
      "Users #{scope_description} - #{lines.join(', ')}."
    end

    # Small function: the answer for a question about one user.
    def detail_text
      users = @payload["users"] || []

      if users.empty?
        return "I did not find a user for \"#{@extra['query']}\"."
      end

      user = users.first
      lines = ["#{user['name']} (#{user['email']}) - status: #{user['status']}"]
      lines << "last login: #{user['last_login_at'] ? format_time(user['last_login_at']) : 'never'}"
      lines << "last activity: #{user['last_activity_at'] ? format_time(user['last_activity_at']) : 'never'}"
      lines << "registered: #{format_time(user['created_at'])}"
      lines.join(", ") + "."
    end

    # Small function: a human readable description of the applied filters.
    # NOTE: the status is optional, because the counting texts already mention
    # it ("5 blocked users ...").
    def scope_description(include_status: true)
      filters = @plan["filters"] || {}
      parts = []

      parts << "with e-mail starting with #{filters['email_prefixes'].join(' or ')}" if filters["email_prefixes"].present?
      parts << "with e-mail containing #{filters['email_contains']}" if filters["email_contains"].present?
      parts << "with name containing #{filters['name_contains']}" if filters["name_contains"].present?
      parts << "from #{filters['domain']}" if filters["domain"].present?
      parts << "matching \"#{filters['q']}\"" if filters["q"].present?
      parts << "that are blocked" if include_status && filters["status"] == "blocked"
      parts << "that are active" if include_status && filters["status"] == "active"

      parts.empty? ? "in the system" : parts.join(" ")
    end

    # Small function: a readable time.
    def format_time(value)
      Time.zone.parse(value.to_s)&.strftime("%Y-%m-%d %H:%M %Z") || value.to_s
    end

    # Small function: the plural forms are always needed in the texts.
    # IMPORTANT: for the number one the singular form is used.
    def plural(count, singular, plural_form = nil)
      return singular if count.to_i == 1

      plural_form || "#{singular}s"
    end

    # Small function: the words for the time windows.
    def window_word(window)
      case window
      when "day" then "24 hours"
      when "week" then "7 days"
      when "month" then "30 days"
      else "period"
      end
    end
  end
end

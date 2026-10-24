# frozen_string_literal: true

module Assistant
  # The deterministic translator: natural language -> structured plan.
  #
  # IMPORTANT: this planner needs no API key and no network access, so the
  # assistant always works. It is a small grammar that recognises the questions
  # and the commands a user really types.
  #
  # NOTA BENE: the planner NEVER produces an answer. It only produces a plan
  # that is executed against the REST API, so a wrong number can never appear.
  class RulePlanner
    # NOTE: words that must not be mistaken for an e-mail prefix.
    STOP_WORDS = %w[the a an and or in of for with emails email mail mails users user that which
                    all any some there here from to start starts starting started begin begins
                    beginning preceded prefix letter letters address addresses].freeze

    def initialize(text)
      @original = text.to_s
      @text = @original.downcase.strip
    end

    # Small function: builds the plan.
    def plan
      return PlanSchema.normalize({ "intent" => "unknown" }) if @text.blank?

      intent = detect_intent
      raw = {
        "intent" => intent,
        "filters" => extract_filters,
        "sort" => detect_sort,
        "direction" => detect_direction,
        "group_by" => detect_group_by,
        "limit" => detect_limit,
        "metric" => detect_metric,
        "never_logged_in" => never_logged_in?
      }

      # IMPORTANT: a command that changes the table does not need the filters
      # of an analytical question - but a filter command does.
      PlanSchema.normalize(raw)
    end

    private

    # Small function: which intent does the sentence describe?
    def detect_intent
      # NOTE: 1) commands - a sentence that STARTS with a verb is a command.
      command = detect_command
      return command if command && imperative?

      # NOTE: 2) commands that explicitly talk about the current selection.
      return command if command && @text.match?(/\bselected\b/)

      # NOTE: 3) analytical questions.
      case @text
      when /\b(how many|number of|count of|count|total|total number)\b/ then "count_users"
      when /\b(status of|when did|last login of|last activity of|who is|info about|information about|details? (of|about))\b/ then "user_detail"
      when /\b(group by|breakdown|by status|by domain|by e-?mail domain)\b/ then "user_stats"
      when /\b(who|which|list|show|display|give me|find|are there)\b/ then "list_users"
      else "unknown"
      end
    end

    # Small function: the command part of a sentence.
    def detect_command
      case @text
      when /\b(clear|reset|remove|uncheck)\s+(the\s+)?(current\s+)?selection\b/ then "clear_selection"
      when /\b(un-?block|unban|un-?ban|restore|reactivate|activate)\b/ then "unblock_users"
      when /\b(block|ban|suspend|disable)\b/ then "block_users"
      when /\b(delete|remove|erase|purge|drop)\b/ then "delete_users"
      when /\bselect\b/ then "select_users"
      when /\bsort\b/ then "sort_by"
      when /\b(filter|show only|only show|display only)\b/ then "set_filter"
      when /\b(refresh|reload|update the table)\b/ then "refresh_table"
      end
    end

    # Small function: does the sentence look like a command (imperative mood)?
    def imperative?
      @text.match?(/\A(please\s+)?(block|un-?block|unban|delete|remove|erase|select|clear|reset|sort|filter|refresh|reload|show|list|display|update)\b/)
    end

    # Small function: all filters of the sentence.
    def extract_filters
      {
        "status" => detect_status,
        "email_prefixes" => detect_prefixes,
        "email_contains" => detect_email_contains,
        "name_contains" => detect_name_contains,
        "domain" => detect_domain,
        "q" => detect_free_text,
        "window" => detect_window
      }
    end

    # Small function: "blocked users" -> status = blocked.
    def detect_status
      return "blocked" if @text.match?(/\b(blocked|banned|suspended|disabled)\b/)
      return "active" if @text.match?(/\b(active|enabled|approved|not blocked)\b/)

      "all"
    end

    # Small function: "e-mails started with s or p" -> ["s", "p"].
    def detect_prefixes
      match = @text.match(/\b(start(?:s|ed|ing)?|begin(?:s|ning)?|began|preceded)\s+(?:with\s+)?([^\?,\.]+)/)
      return [] unless match

      candidates = match[2].split(/\s+or\s+|,|\s+/)
      cleaned = candidates.map { |word| word.gsub(/[^a-z0-9@._\-]/, "") }.reject(&:blank?)
      # NOTE: stop words are removed, otherwise "started with s or p in the title"
      # would produce the prefix "in".
      cleaned.reject! { |word| STOP_WORDS.include?(word) }
      cleaned.first(10)
    end

    # Small function: "e-mails containing acme" -> "acme".
    def detect_email_contains
      match = @text.match(/\be-?mails?\s+(?:that\s+|which\s+|whose\s+)?(?:contains?|containing|includes?|including)\s+["']?([^\?,\.]+)/)
      return nil unless match

      value = match[1].gsub(/[^a-z0-9@._\- ]/, " ").split(/\s+/).reject { |w| STOP_WORDS.include?(w) }.first(3)
      value.join(" ").presence
    end

    # Small function: "names containing john" -> "john".
    def detect_name_contains
      match = @text.match(/\bnames?\s+(?:that\s+|which\s+|whose\s+)?(?:contains?|containing|includes?|including)\s+["']?([^\?,\.]+)/)
      return nil unless match

      value = match[1].gsub(/[^a-z0-9\s\-]/, " ").split(/\s+/).reject { |w| STOP_WORDS.include?(w) }.first(3)
      value.join(" ").presence
    end

    # Small function: "from gmail.com" -> "gmail.com".
    def detect_domain
      match = @text.match(/@([a-z0-9\-]+(?:\.[a-z0-9\-]+)+)/) || @text.match(/\bfrom\s+([a-z0-9\-]+(?:\.[a-z0-9\-]+)+)\b/)
      match && match[1].downcase
    end

    # Small function: a concrete e-mail or a quoted name mentioned in the text.
    def detect_free_text
      match = @original.match(/[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}/i)
      return match[0].downcase if match

      quoted = @original.match(/"([^"]+)"|'([^']+)'/)
      return (quoted[1] || quoted[2]).strip if quoted

      nil
    end

    # Small function: "today", "this week", "this month".
    def detect_window
      return "day" if @text.match?(/\b(today|to-?day|last 24 hours?|past 24 hours?|past day)\b/)
      return "week" if @text.match?(/\b(this week|last 7 days|past week|seven days)\b/)
      return "month" if @text.match?(/\b(this month|last 30 days|past month|thirty days)\b/)

      "all"
    end

    # Small function: is the question about the registration or about the
    # login? ("how many users registered this week" vs. "how many users
    # logged in this week")
    def detect_metric
      return "registration" if @text.match?(/\b(register|registered|registration|sign(?:ed)? up|signup|joined|created)\b/)

      "login"
    end

    # Small function: "never logged in".
    def never_logged_in?
      @text.match?(/\bnever (logged|logged in|signed in|been active)\b/)
    end

    # Small function: "sort by last login" -> "last_login_at".
    def detect_sort
      match = @text.match(/\bsort(?:ed|ing)?\s+by\s+(?:the\s+)?([a-z\s\-]+)/)
      return "last_login_at" unless match

      phrase = match[1]
      case phrase
      when /name/ then "name"
      when /e-?mail/ then "email"
      when /last login|login time|logins/ then "last_login_at"
      when /last activity|activity/ then "last_activity_at"
      when /status/ then "status"
      when /created|registered|sign(?:ed)? up/ then "created_at"
      else "last_login_at"
      end
    end

    # Small function: "ascending" / "descending".
    def detect_direction
      return "asc" if @text.match?(/\b(ascending|asc|oldest first|first)\b/)
      return "desc" if @text.match?(/\b(descending|desc|newest first|last)\b/)

      "desc"
    end

    # Small function: "by status" / "by domain".
    def detect_group_by
      return "status" if @text.match?(/\b(?:by|per|group by)\s+status\b/)
      return "domain" if @text.match?(/\b(?:by|per|group by)\s+(?:e-?mail\s+)?domain\b/)

      "none"
    end

    # Small function: "top 5 users" -> limit = 5.
    def detect_limit
      match = @text.match(/\btop\s+(\d{1,3})\b/) || @text.match(/\b(\d{1,3})\s+(?:first|top)\b/)
      match ? match[1].to_i.clamp(1, 100) : 25
    end
  end
end

# frozen_string_literal: true

module Assistant
  # The contract of a "plan" - the structured translation of a natural language
  # question or command.
  #
  # IMPORTANT: a plan is DATA, not code. Whatever produced it (a large language
  # model or the deterministic grammar) the plan is validated here, against a
  # whitelist. A model can therefore never inject SQL, an unknown column or an
  # unknown operation.
  class PlanSchema
    # NOTE: every intent the application understands.
    INTENTS = %w[
      count_users
      list_users
      user_stats
      user_detail
      select_users
      clear_selection
      block_users
      unblock_users
      delete_users
      set_filter
      sort_by
      refresh_table
      unknown
    ].freeze

    STATUSES = %w[active blocked all].freeze
    DIRECTIONS = %w[asc desc].freeze
    GROUPS = %w[none status domain].freeze
    WINDOWS = %w[all day week month].freeze
    # NOTE: which counter the question is about - the login time or the
    # registration date.
    METRICS = %w[login registration].freeze
    SORT_COLUMNS = UserQuery::SORT_COLUMNS.keys.freeze

    # NOTE: the JSON schema handed over to a large language model, so that it
    # can only answer with a valid plan.
    def self.json_schema
      {
        type: "object",
        additionalProperties: false,
        required: %w[intent filters sort direction group_by limit],
        properties: {
          intent: { type: "string", enum: INTENTS },
          filters: {
            type: "object",
            additionalProperties: false,
            required: %w[status email_prefixes email_contains name_contains domain q window],
            properties: {
              status: { type: "string", enum: STATUSES },
              email_prefixes: { type: "array", items: { type: "string" } },
              email_contains: { type: "string" },
              name_contains: { type: "string" },
              domain: { type: "string" },
              q: { type: "string" },
              window: { type: "string", enum: WINDOWS }
            }
          },
          sort: { type: "string", enum: SORT_COLUMNS },
          direction: { type: "string", enum: DIRECTIONS },
          group_by: { type: "string", enum: GROUPS },
          limit: { type: "integer", minimum: 1, maximum: 100 },
          metric: { type: "string", enum: METRICS },
          never_logged_in: { type: "boolean" }
        }
      }
    end

    # Small function: cleans and validates a plan.
    # IMPORTANT: unknown values are replaced by safe defaults - the planner
    # never crashes and never produces an executable garbage plan.
    def self.normalize(raw)
      raw = {} unless raw.is_a?(Hash)
      filters = raw["filters"].is_a?(Hash) ? raw["filters"] : {}

      {
        "intent" => INTENTS.include?(raw["intent"].to_s) ? raw["intent"].to_s : "unknown",
        "filters" => {
          "status" => STATUSES.include?(filters["status"].to_s) ? filters["status"].to_s : "all",
          "email_prefixes" => Array(filters["email_prefixes"]).map { |v| v.to_s.strip.downcase.delete_prefix("@") }
                                  .reject(&:blank?).uniq.first(10),
          "email_contains" => filters["email_contains"].to_s.strip.presence,
          "name_contains" => filters["name_contains"].to_s.strip.presence,
          "domain" => filters["domain"].to_s.strip.downcase.delete_prefix("@").presence,
          "q" => filters["q"].to_s.strip.presence,
          "window" => WINDOWS.include?(filters["window"].to_s) ? filters["window"].to_s : "all"
        },
        "sort" => SORT_COLUMNS.include?(raw["sort"].to_s) ? raw["sort"].to_s : "last_login_at",
        "direction" => DIRECTIONS.include?(raw["direction"].to_s) ? raw["direction"].to_s : "desc",
        "group_by" => GROUPS.include?(raw["group_by"].to_s) ? raw["group_by"].to_s : "none",
        "limit" => raw["limit"].to_i.clamp(1, 100),
        "metric" => METRICS.include?(raw["metric"].to_s) ? raw["metric"].to_s : "login",
        "never_logged_in" => [true, false].include?(raw["never_logged_in"]) ? raw["never_logged_in"] : false
      }
    end
  end
end

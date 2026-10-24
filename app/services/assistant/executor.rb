# frozen_string_literal: true

module Assistant
  # Executes a plan.
  #
  # IMPORTANT: the executor is the only place that talks to the API. It
  #  1. translates the sentence into a plan (Planner),
  #  2. calls the REST API with that plan,
  #  3. builds the answer text from the API payload (AnswerFormatter).
  #
  # NOTA BENE: the answer is NEVER produced by a language model. The model (if
  # any) only helps with step 1.
  class Executor
    # NOTE: the endpoints of the REST API.
    LIST_PATH = "/api/v1/users"
    STATS_PATH = "/api/v1/users/stats"

    def initialize(text:, selected_ids: [], client: nil)
      @text = text.to_s
      @selected_ids = Array(selected_ids).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
      @client = client || ApiClient.new
    end

    # Small function: runs everything and returns the answer.
    def call
      planner_result = Planner.new(@text).call
      plan = planner_result["plan"]
      engine = planner_result["engine"]

      result = {
        "question" => @text,
        "engine" => engine,
        "plan" => plan,
        "answer" => "",
        "api_calls" => [],
        "ui_actions" => [],
        "data" => {}
      }

      case plan["intent"]
      when "count_users", "user_stats" then execute_statistics(result, plan)
      when "list_users", "user_detail" then execute_list(result, plan)
      when "select_users" then execute_select(result, plan)
      when "clear_selection" then execute_simple(result, plan, "clear_selection")
      when "set_filter" then execute_simple(result, plan, "set_filter")
      when "sort_by" then execute_simple(result, plan, "sort_by")
      when "refresh_table" then execute_simple(result, plan, "refresh_table")
      when "block_users", "unblock_users", "delete_users" then execute_bulk(result, plan)
      else execute_unknown(result, plan)
      end

      result
    end

    private

    # Small function: a question about numbers -> GET /api/v1/users/stats.
    def execute_statistics(result, plan)
      payload, call = fetch_stats(plan)
      result["api_calls"] << call
      result["data"] = payload

      result["answer"] = AnswerFormatter.new(intent: plan["intent"], plan: plan, payload: payload).call
    end

    # Small function: a question about the users -> GET /api/v1/users.
    def execute_list(result, plan)
      payload, call = fetch_list(plan)
      result["api_calls"] << call
      result["data"] = payload

      extra = { "query" => plan.dig("filters", "q").to_s }
      result["answer"] = AnswerFormatter.new(intent: plan["intent"], plan: plan, payload: payload, extra: extra).call
    end

    # Small function: "select users with e-mails started with s or p".
    def execute_select(result, plan)
      payload, call = fetch_list(plan)
      result["api_calls"] << call

      users = payload["users"] || []
      ids = users.map { |user| user["id"] }
      result["data"] = payload

      # IMPORTANT: the ids are handed over to the browser, which ticks the
      # checkboxes of exactly these rows.
      result["ui_actions"] << { "type" => "select_users", "ids" => ids, "count" => ids.size }
      result["ui_actions"] << { "type" => "set_filter", "filters" => plan["filters"] }
      result["ui_actions"] << { "type" => "sort_by", "sort" => plan["sort"], "direction" => plan["direction"] }

      extra = { "count" => ids.size }
      result["answer"] = AnswerFormatter.new(intent: "select_users", plan: plan, payload: payload, extra: extra).call
    end

    # Small function: the commands that only change the view.
    def execute_simple(result, plan, intent)
      case intent
      when "clear_selection"
        result["ui_actions"] << { "type" => "clear_selection" }
      when "set_filter"
        result["ui_actions"] << { "type" => "set_filter", "filters" => plan["filters"] }
      when "sort_by"
        result["ui_actions"] << { "type" => "sort_by", "sort" => plan["sort"], "direction" => plan["direction"] }
      when "refresh_table"
        result["ui_actions"] << { "type" => "reload" }
      end

      result["answer"] = AnswerFormatter.new(intent: intent, plan: plan, payload: {}).call
    end

    # Small function: "block the selected users" -> POST /api/v1/users/bulk_block.
    def execute_bulk(result, plan)
      ids, call = resolve_target_ids(plan)
      result["api_calls"] << call if call

      if ids.empty?
        result["answer"] = "There is nothing to do - no user is selected and the command does not " \
                            "describe which users to take."
        return
      end

      path = case plan["intent"]
             when "block_users" then "/api/v1/users/bulk_block"
             when "unblock_users" then "/api/v1/users/bulk_unblock"
             else "/api/v1/users/bulk_delete"
             end

      bulk_call = @client.post(path, { "user_ids" => ids })
      result["api_calls"] << bulk_call

      # NOTE: the fallback keeps the assistant usable when the process cannot
      # reach itself (for example in the test suite).
      payload = bulk_call.ok? ? bulk_call.body : UserBulkAction.call(operation_of(path), ids)
      count = payload.is_a?(Hash) ? payload["count"].to_i : ids.size
      result["data"] = payload if payload.is_a?(Hash)

      # IMPORTANT: after a destructive operation the table has to be reloaded,
      # because the rows are gone or their status has changed.
      result["ui_actions"] << { "type" => "reload" }

      extra = { "count" => count }
      result["answer"] = AnswerFormatter.new(intent: plan["intent"], plan: plan, payload: {}, extra: extra).call
    end

    # Small function: nothing understood.
    def execute_unknown(result, plan)
      result["answer"] = AnswerFormatter.new(intent: "unknown", plan: plan, payload: {}).call
    end

    # Small function: the operation name of a bulk endpoint.
    def operation_of(path)
      case path
      when /bulk_block/ then "block"
      when /bulk_unblock/ then "unblock"
      else "delete"
      end
    end

    # Small function: which users does the command talk about?
    # IMPORTANT: if the command names the selection ("the selected users") the
    # selection of the browser is used, otherwise the users are looked up with
    # the filters of the plan.
    def resolve_target_ids(plan)
      filters = plan["filters"] || {}
      describing_filters = filters["email_prefixes"].present? || filters["email_contains"].present? ||
                          filters["name_contains"].present? || filters["domain"].present? ||
                          filters["q"].present? || filters["status"] != "all"

      if @text.match?(/\bselected\b/) || !describing_filters
        return [@selected_ids, nil]
      end

      payload, call = fetch_list(plan)
      [(payload["users"] || []).map { |user| user["id"] }, call]
    end

    # Small function: GET /api/v1/users (with a safe in-process fallback).
    def fetch_list(plan)
      params = query_params(plan)
      call = @client.get(LIST_PATH, params)

      if call.ok?
        [call.body, call]
      else
        # NOTE: the fallback keeps the assistant usable when the process cannot
        # reach itself (for example in the test suite).
        [build_list_payload(params), call]
      end
    end

    # Small function: GET /api/v1/users/stats (with a safe in-process fallback).
    def fetch_stats(plan)
      params = query_params(plan).merge("group_by" => plan["group_by"])
      call = @client.get(STATS_PATH, params)

      if call.ok?
        [call.body, call]
      else
        [build_stats_payload(params), call]
      end
    end

    # Small function: the query parameters of the API, built from the plan.
    def query_params(plan)
      filters = plan["filters"] || {}
      params = {
        "q" => filters["q"],
        "email_prefixes" => filters["email_prefixes"].presence&.join(","),
        "email_contains" => filters["email_contains"],
        "name_contains" => filters["name_contains"],
        "domain" => filters["domain"],
        "status" => filters["status"],
        "window" => filters["window"],
        "sort" => plan["sort"],
        "direction" => plan["direction"],
        "limit" => plan["limit"]
      }
      params.compact
    end

    # Small function: the fallback for the list endpoint.
    def build_list_payload(params)
      query = UserQuery.new(params)
      scope = query.scope
      total = scope.count
      users = scope.order(query.order_clause).limit(query.limit).offset(query.offset).to_a

      {
        "query" => query.filters,
        "total_count" => total,
        "returned_count" => users.size,
        "users" => users.map { |user| UserQuery.serialize(user) }
      }
    end

    # Small function: the fallback for the statistics endpoint.
    def build_stats_payload(params)
      UserQuery.new(params).statistics
    end
  end
end

# frozen_string_literal: true

# A single place that knows HOW to ask the database a question about users.
#
# IMPORTANT: the AI (and the natural language layer) must NOT read the table
# and count rows on its own - models are bad at counting. Instead every
# question is translated into a structured query, this class executes it in
# SQL, and the API returns the numbers that PostgreSQL computed.
#
# NOTA BENE: this class is used by BOTH the HTTP API (app/controllers/api) and
# the natural language planner, so the assistant and the API always agree.
class UserQuery
  DEFAULT_LIMIT = 25
  MAX_LIMIT = 100

  # NOTE: whitelist of the sortable columns - a user can never inject SQL.
  SORT_COLUMNS = {
    "name" => "users.name",
    "email" => "users.email",
    "position" => "users.position",
    "last_login_at" => "users.last_login_at",
    "last_activity_at" => "users.last_activity_at",
    "status" => "users.blocked",
    "created_at" => "users.created_at"
  }.freeze

  # NOTE: the supported time windows used by the "activity" statistics.
  WINDOWS = { "day" => 1, "week" => 7, "month" => 30 }.freeze

  def initialize(params = {})
    # NOTE: the controller passes ActionController::Parameters, the services
    # pass a plain Hash. Both are accepted here.
    source = params || {}
    source = source.to_unsafe_h if source.respond_to?(:to_unsafe_h)
    @params = source.to_h.with_indifferent_access
  end

  # Small function: the normalised, echo-friendly description of the filters.
  # IMPORTANT: the assistant sends this description back to the user, so it
  # must show exactly what was really applied.
  def filters
    {
      "q" => @params[:q].to_s.strip.presence,
      "email_prefixes" => prefixes,
      "email_contains" => @params[:email_contains].to_s.strip.presence,
      "name_contains" => @params[:name_contains].to_s.strip.presence,
      "domain" => domain,
      "status" => status,
      "window" => window
    }.reject { |_key, value| value.blank? || value == [] }
  end

  # Small function: the ActiveRecord scope described by the filters.
  def scope
    scope = User.all
    scope = scope.active  if status == "active"
    scope = scope.blocked if status == "blocked"

    if @params[:q].present?
      # NOTE: the value is passed as a bind parameter, never interpolated.
      pattern = "%#{User.sanitize_sql_like(@params[:q].to_s.strip.downcase)}%"
      scope = scope.where("LOWER(users.name) LIKE :pattern OR LOWER(users.email) LIKE :pattern", pattern: pattern)
    end

    if @params[:email_contains].present?
      pattern = "%#{User.sanitize_sql_like(@params[:email_contains].to_s.strip.downcase)}%"
      scope = scope.where("LOWER(users.email) LIKE :pattern", pattern: pattern)
    end

    if @params[:name_contains].present?
      pattern = "%#{User.sanitize_sql_like(@params[:name_contains].to_s.strip.downcase)}%"
      scope = scope.where("LOWER(users.name) LIKE :pattern", pattern: pattern)
    end

    # NOTE: several prefixes can be given at once ("started with s or p").
    # IMPORTANT: they are combined with OR - "s or p" means "s" OR "p".
    unless prefixes.empty?
      binds = {}
      conditions = prefixes.each_with_index.map do |prefix, index|
        # NOTE: the bind parameters are symbols - that is the way Rails binds
        # the named placeholders.
        name = "prefix_#{index}".to_sym
        binds[name] = "#{prefix.downcase}%"
        "LOWER(users.email) LIKE :#{name}"
      end

      scope = scope.where(conditions.join(" OR "), binds)
    end

    if domain.present?
      scope = scope.where("LOWER(users.email) LIKE ?", "%@#{domain}")
    end

    scope
  end

  # Small function: the ORDER BY clause (whitelisted column + direction).
  def order_clause
    column = SORT_COLUMNS.fetch(sort_column)
    direction = sort_direction == "asc" ? "ASC" : "DESC"

    if sort_column == "status"
      "users.blocked #{direction}, users.email ASC"
    elsif %w[last_login_at last_activity_at].include?(sort_column)
      # IMPORTANT: accounts that never logged in always go to the bottom.
      "#{column} #{direction} NULLS LAST, users.email ASC"
    else
      "#{column} #{direction}, users.email ASC"
    end
  end

  # NOTE: the list endpoint payload - the JSON shape of a user row.
  def self.serialize(user)
    {
      "id" => user.id,
      "name" => user.name,
      "email" => user.email,
      "position" => user.position,
      "status" => user.status_label.downcase,
      "blocked" => user.blocked?,
      "last_login_at" => user.last_login_at&.iso8601,
      "last_activity_at" => user.last_activity_at&.iso8601,
      "created_at" => user.created_at.iso8601,
      "email_domain" => user.email.to_s.split("@").last.to_s.downcase
    }
  end

  # IMPORTANT: all the numbers of the statistics endpoint.
  # NOTE: every number is produced by the database (COUNT(*) with filters), so
  # the assistant can never "guess" a wrong value.
  def statistics
    base = scope
    now = Time.current

    totals = {
      "users" => base.count,
      "active" => base.active.count,
      "blocked" => base.blocked.count
    }

    activity = {
      "last_login_24h" => base.where(last_login_at: (now - 1.day)..now).count,
      "last_login_7d" => base.where(last_login_at: (now - 7.days)..now).count,
      "last_login_30d" => base.where(last_login_at: (now - 30.days)..now).count,
      "last_login_ever" => base.where.not(last_login_at: nil).count,
      "never_logged_in" => base.where(last_login_at: nil).count,
      "registered_24h" => base.where(created_at: (now - 1.day)..now).count,
      "registered_7d" => base.where(created_at: (now - 7.days)..now).count,
      "registered_30d" => base.where(created_at: (now - 30.days)..now).count,
      "active_last_24h" => base.where(last_activity_at: (now - 1.day)..now).count
    }

    {
      "filters" => filters,
      "totals" => totals,
      "overall" => overall_totals,
      "activity" => activity,
      "groups" => groups
    }
  end

  # IMPORTANT: the numbers of the whole table - without any filter. The
  # assistant needs them to say "5 blocked users (26 users in total)".
  def overall_totals
    {
      "users" => User.count,
      "active" => User.active.count,
      "blocked" => User.blocked.count
    }
  end

  # NOTE: the grouped counters (by status, by e-mail domain, ...).
  def groups
    case group_by
    when "domain"
      # IMPORTANT: the domain is taken from the e-mail in SQL, not in Ruby.
      scope.group(Arel.sql("LOWER(SPLIT_PART(users.email, '@', 2))"))
           .order(Arel.sql("COUNT(*) DESC, 1 ASC"))
           .count
           .map { |key, count| { "key" => key.to_s, "count" => count } }
    when "status"
      [
        { "key" => "active", "count" => scope.active.count },
        { "key" => "blocked", "count" => scope.blocked.count }
      ]
    else
      []
    end
  end

  # Small helpers (kept tiny on purpose).
  def sort_column
    value = @params[:sort].to_s
    SORT_COLUMNS.key?(value) ? value : "last_login_at"
  end

  def sort_direction
    @params[:direction].to_s == "asc" ? "asc" : "desc"
  end

  def status
    value = @params[:status].to_s
    %w[active blocked all].include?(value) ? value : "all"
  end

  # Small function: the e-mail domain the query is limited to.
  def domain
    @params[:domain].to_s.strip.downcase.delete_prefix("@").presence
  end

  def window
    value = @params[:window].to_s
    WINDOWS.key?(value) ? value : "all"
  end

  def group_by
    value = @params[:group_by].to_s
    %w[domain status].include?(value) ? value : "none"
  end

  def limit
    value = @params[:limit].to_i
    return DEFAULT_LIMIT if value <= 0

    [value, MAX_LIMIT].min
  end

  def offset
    @params[:offset].to_i.negative? ? 0 : @params[:offset].to_i
  end

  # NOTE: the list of e-mail prefixes, e.g. ["s", "p"].
  def prefixes
    raw = @params[:email_prefixes] || @params[:email_prefix]
    list = case raw
           when Array then raw
           when String then raw.split(/[,\s]+/)
           else []
           end
    list.map { |value| value.to_s.strip.downcase.delete_prefix("@") }.reject(&:blank?).uniq
  end
end

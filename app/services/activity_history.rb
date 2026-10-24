# frozen_string_literal: true

# Builds the small bar charts (the sparklines) under the "last activity"
# column of the table.
#
# IMPORTANT: the counters are computed with ONE query for the whole table -
# not one query per row. The counts of every user are grouped by the day, so
# that the chart of a user is a list of the last fourteen days.
class ActivityHistory
  # NOTE: the number of the bars of the chart (one bar per day).
  DAYS = 14

  # Small function: the counts of the activity of the given users.
  #
  # NOTA BENE: the result is a hash with the id of the user as the key and the
  # counts of the days (the oldest day first) as the value.
  def self.for_users(users)
    ids = Array(users).map(&:id)
    return {} if ids.empty?

    # NOTE: exactly DAYS days - the chart has one bar per day.
    since = (DAYS - 1).days.ago.to_date

    # NOTE: one query for all the users - the database groups the rows.
    rows = UserActivity
           .where(user_id: ids)
           .where(occurred_at: since.beginning_of_day..)
           .group(:user_id, Arel.sql("DATE(occurred_at)"))
           .count

    # NOTE: the empty days are filled with a zero, so that every chart has
    # the same number of bars.
    days = (since..Date.current).to_a

    ids.index_with do |user_id|
      days.map { |day| rows.fetch([user_id, day], 0) }
    end
  end
end

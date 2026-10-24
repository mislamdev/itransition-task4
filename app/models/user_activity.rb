# frozen_string_literal: true

# One entry of the activity history of an account.
#
# IMPORTANT: the rows are the source of the small bar chart under the "last
# activity" column of the table.
class UserActivity < ApplicationRecord
  belongs_to :user

  # NOTE: only the activity of the last days is interesting for the chart.
  scope :recent, ->(since = 14.days.ago) { where(occurred_at: since..) }

  # Small function: the activity is recorded at most once per minute, so that
  # a user that browses the table does not fill the table with rows.
  def self.record(user, at: Time.current)
    last = where(user_id: user.id).order(occurred_at: :desc).limit(1).pick(:occurred_at)
    return nil if last && last > 1.minute.ago

    create!(user_id: user.id, occurred_at: at)
  end
end

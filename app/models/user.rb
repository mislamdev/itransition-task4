# frozen_string_literal: true

# The only domain model of the application: a user account.
#
# NOTE: the model is intentionally thin. All uniqueness / blocking rules that
# must hold "no matter what" are enforced by the DATABASE (unique index) and by
# the authentication filter in ApplicationController - not by this class alone.
class User < ApplicationRecord
  # NOTE: has_secure_password (Active Model) hashes the password with bcrypt.
  # We never implement crypto ourselves - the library does it. The plain
  # password is not stored anywhere, only `password_digest` is.
  has_secure_password

  # NOTE: the history of the activity of the account - it is the source of the
  # small bar chart under the "last activity" column. IMPORTANT: the history
  # belongs to the account, therefore it is deleted together with it.
  has_many :user_activities, dependent: :delete_all

  # IMPORTANT: the e-mail is the business key of a user, so it is normalised
  # (trimmed + down-cased) before every validation. That makes the plain unique
  # index on `email` behave case-insensitively.
  before_validation :normalize_email

  validates :name, presence: true, length: { minimum: 1, maximum: 120 }

  # NOTE: the uniqueness validation gives a friendly message in the browser.
  # It is only a courtesy - the REAL protection is the unique index, see
  # db/migrate/20260101000001_create_users.rb
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid e-mail address" }

  # NOTE: the task allows ANY non-empty password, even a single character.
  # Therefore the minimum length is 1 and there is no complexity rule.
  validates :password, length: { minimum: 1, message: "must not be empty" }, allow_nil: true

  # Scope used by the admin table and by the query API.
  scope :active,  -> { where(blocked: false) }
  scope :blocked, -> { where(blocked: true) }

  # NOTE: the default ordering of the admin table is "the most recent login
  # first" - the task requires the data in the UI to be sorted.
  scope :sorted_by_last_login, lambda {
    order(Arel.sql("last_login_at DESC NULLS LAST, id DESC"))
  }

  # Small helper: the label shown in the "Status" column.
  def status_label
    blocked? ? "Blocked" : "Active"
  end

  # Small helper: the CSS modifier used by the Bootstrap badge.
  def status_badge_class
    blocked? ? "text-bg-danger" : "text-bg-success"
  end

  # IMPORTANT: called right after a successful sign in.
  # NOTA BENE: `last_login_at` and `last_activity_at` are two different things:
  #   - last_login_at   -> the moment of the last successful authentication
  #   - last_activity_at-> the moment of the last authenticated request
  def record_login!
    now = Time.current
    update_columns(last_login_at: now, last_activity_at: now, updated_at: now)
  end

  # Small function: remembers that the user did something inside the app.
  # NOTE: update_columns skips validations & callbacks on purpose - it must be
  # cheap and it must never fail because of some unrelated validation.
  def touch_activity!
    update_columns(last_activity_at: Time.current, updated_at: Time.current)
  end

  private

  # Small function, but an important one: it lower-cases the e-mail so that
  # "Bob@Example.COM" and "bob@example.com" are the SAME account.
  # NOTE: the unique index on lower(email) in the database is the last line of
  # defence for the case where the model is bypassed.
  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end

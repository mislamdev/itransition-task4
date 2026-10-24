# frozen_string_literal: true

# The demo data of the application.
#
# IMPORTANT: the seeds are idempotent - they can be executed again without
# creating the same user twice (the e-mail is the unique key).
#
# NOTA BENE: the password of every demo account is "demo" - a single
# character is enough for this application, so even "a" would work.

DEMO_PASSWORD = "demo"

# NOTE: the accounts of the data set of the task (users.json) are imported
# below. These few accounts are additional, they make it easy to sign in and
# they show the different cases (blocked, never logged in, ...).
USERS = [
  { name: "Ada Lovelace",     email: "ada@example.com",       blocked: false, last_login_at: 1.hour.ago },
  { name: "Alan Turing",      email: "alan@example.com",      blocked: false, last_login_at: 5.hours.ago },
  { name: "Grace Hopper",     email: "grace@example.com",     blocked: false, last_login_at: 2.days.ago },
  { name: "Katherine Johnson",email: "katherine@example.com", blocked: false, last_login_at: 3.days.ago },
  { name: "Linus Torvalds",   email: "linus@example.com",     blocked: false, last_login_at: 4.days.ago },
  { name: "Barbara Liskov",   email: "barbara@example.com",   blocked: false, last_login_at: 6.days.ago },
  { name: "Margaret Hamilton",email: "margaret@example.com",  blocked: false, last_login_at: 8.days.ago },
  { name: "Tim Berners-Lee",  email: "tim@example.com",       blocked: false, last_login_at: nil },
  { name: "Radia Perlman",    email: "radia@example.com",     blocked: true,  last_login_at: 12.days.ago },
  { name: "Shafi Goldwasser", email: "shafi@example.com",     blocked: true,  last_login_at: 15.days.ago },
  { name: "Peter Norvig",     email: "peter@example.com",     blocked: false, last_login_at: 20.hours.ago },
  { name: "Paul Erdős",       email: "paul@example.com",      blocked: false, last_login_at: 9.days.ago },
  { name: "Sophie Wilson",    email: "sophie@example.com",    blocked: false, last_login_at: 30.hours.ago },
  { name: "Sam Wilkinson",    email: "sam@example.com",       blocked: false, last_login_at: 2.hours.ago },
  { name: "Sofia Kovalevskaya", email: "sofia@example.com",   blocked: true,  last_login_at: 25.days.ago },
  { name: "Sarah Smith",      email: "sarah@gmail.com",       blocked: false, last_login_at: 7.days.ago },
  { name: "Peter Novak",      email: "peter.novak@gmail.com", blocked: false, last_login_at: 11.days.ago },
  { name: "Sergei Pavlov",    email: "sergei@gmail.com",      blocked: false, last_login_at: 13.days.ago },
  { name: "Olga Petrova",     email: "olga@gmail.com",        blocked: true,  last_login_at: 40.days.ago },
  { name: "Paula Silva",      email: "paula@outlook.com",     blocked: false, last_login_at: 1.day.ago },
  { name: "Pedro Alvarez",    email: "pedro@outlook.com",     blocked: false, last_login_at: 18.days.ago },
  { name: "Priya Sharma",     email: "priya@outlook.com",     blocked: false, last_login_at: 5.days.ago },
  { name: "Steve Wozniak",    email: "steve@outlook.com",     blocked: true,  last_login_at: 55.days.ago },
  { name: "Susan Kare",       email: "susan@outlook.com",     blocked: false, last_login_at: 16.days.ago },
  { name: "Satoshi Nakamoto", email: "satoshi@example.com",   blocked: false, last_login_at: 21.days.ago },
  { name: "Xavier Brown",     email: "xavier@example.com",    blocked: false, last_login_at: 22.days.ago }
].freeze

puts "== Seeding the demo users =="

USERS.each do |attributes|
  user = User.find_or_initialize_by(email: attributes[:email])
  user.name = attributes[:name]
  user.blocked = attributes[:blocked]
  user.password = DEMO_PASSWORD
  user.password_confirmation = DEMO_PASSWORD
  user.last_login_at = attributes[:last_login_at]
  user.last_activity_at = attributes[:last_login_at]
  user.save!

  print "."
end

puts

# ---------------------------------------------------------------------------
# The data set of the task (users.json).
#
# IMPORTANT: the file contains 200 accounts with a name, an e-mail, a
# position, the last activity and the status. They are imported into the
# database, so that the table shows a realistic amount of data.
# ---------------------------------------------------------------------------
DATA_FILE = Rails.root.join("users.json")

if File.exist?(DATA_FILE)
  puts "== Importing the data set of the task (users.json) =="

  records = JSON.parse(File.read(DATA_FILE))
  imported = 0
  skipped = 0

  records.each do |record|
    email = record["email"].to_s.strip.downcase
    next if email.blank?

    user = User.find_or_initialize_by(email: email)
    user.name = record["full_name"].to_s
    user.position = record["job_position"].to_s
    user.blocked = record["status"].to_s.casecmp?("blocked")

    # NOTE: the data set knows the last activity of an account - it is used
    # for the last login time and for the last activity time.
    last_seen = Time.zone.parse(record["last_seen"].to_s)
    user.last_login_at = last_seen
    user.last_activity_at = last_seen

    user.password = DEMO_PASSWORD
    user.password_confirmation = DEMO_PASSWORD
    user.save!

    imported += 1
    print "."
  end

  puts
  puts "#{imported} accounts imported (#{skipped} skipped)."
else
  puts "No users.json found - only the demo accounts were created."
end

puts "#{User.count} users in the database."
puts "Sign in with any of the e-mail addresses above and the password '#{DEMO_PASSWORD}'."

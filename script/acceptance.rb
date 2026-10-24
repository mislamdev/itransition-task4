# frozen_string_literal: true

# The acceptance test of the DEPLOYED application.
#
# It drives the public URL exactly like a browser would: it registers, signs
# in, uses the toolbar, blocks a user, deletes a user and checks that a
# blocked or deleted account is sent back to the login form.
#
# Usage: bundle exec ruby script/acceptance.rb https://<public url>

require "net/http"
require "uri"
require "json"

BASE = (ARGV[0] || "http://127.0.0.1:3100").chomp("/")

PASSED = []
FAILED = []

# NOTE: the cookie jars of the two "browsers" of the test:
# ADMIN   - the administrator that uses the toolbar
# OTHER   - the second account that is blocked and deleted
ADMIN = {}
OTHER = {}

# Small function: checks one expectation.
def check(description)
  ok = yield
  if ok
    PASSED << description
    puts "  PASS  #{description}"
  else
    FAILED << description
    puts "  FAIL  #{description}"
  end
rescue StandardError => e
  FAILED << description
  puts "  FAIL  #{description} (#{e.class}: #{e.message})"
end

# Small function: the cookies of a response.
def cookies_of(response)
  Array(response.get_fields("set-cookie")).each_with_object({}) do |cookie, jar|
    name, value = cookie.split(";").first.split("=", 2)
    jar[name] = value
  end
end

# Small function: one HTTP request with the cookie jar of the browser.
def request(method, path, jar: ADMIN, body: nil, headers: {}, form: nil)
  uri = URI.parse("#{BASE}#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
  req = klass.new(uri)
  headers.each { |key, value| req[key] = value }
  req["Cookie"] = jar.map { |key, value| "#{key}=#{value}" }.join("; ") unless jar.empty?

  if form
    req.set_form_data(flatten_form(form))
  elsif body
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(body)
  end

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }

  # IMPORTANT: the newest cookies win, like in a browser.
  jar.merge!(cookies_of(response))
  response
end

# Small function: a flat form hash ("user" => { "name" => "x" } becomes
# "user[name]" => "x") - that is what a browser sends.
def flatten_form(form, prefix = nil)
  form.each_with_object({}) do |(key, value), result|
    name = prefix ? "#{prefix}[#{key}]" : key.to_s
    if value.is_a?(Hash)
      result.merge!(flatten_form(value, name))
    elsif value.is_a?(Array)
      # NOTE: an array becomes the field name with brackets - that is what a
      # browser sends for a group of checkboxes.
      value.each { |item| result["#{name}[]"] = item.to_s }
    else
      result[name] = value.to_s
    end
  end
end

# Small function: the CSRF token of a page.
def token_of(html, name = "authenticity_token")
  html.to_s[/name="#{name}"(?: value| content)="([^"]+)"/, 1]
end

# Small function: a form POST with the CSRF token of the page.
def post_form(path, form, jar: ADMIN, token_page: nil)
  page = request(:get, token_page || path, jar: jar)
  token = token_of(page.body) || token_of(page.body, "csrf-token")

  if token.nil?
    # NOTE: the page was a redirect (a signed in user does not see the login
    # form) -> the table always carries the token of the session.
    page = request(:get, "/users", jar: jar)
    token = token_of(page.body, "csrf-token")
  end

  request(:post, path, jar: jar, form: form.merge("authenticity_token" => token.to_s))
end

# Small function: the id of a user in the table.
def id_of(html, email)
  html.scan(/<tr data-user-id="(\d+)"[^>]*>(.*?)<\/tr>/m).each do |id, row|
    return id if row.include?(email)
  end
  nil
end

puts "== Acceptance test of #{BASE} =="

email = "acceptance-#{Time.now.to_i}@example.com"
password = "a"

puts "\n-- registration"
response = post_form("/signup", { "user" => { "name" => "Acceptance Test", "email" => email, "password" => password, "password_confirmation" => password } })
check("the registration redirects to the login form") { response.code == "302" && response["location"].to_s.end_with?("/login") }

page = request(:get, "/login")
check("the success message is shown") { page.body.include?("Registration successful") }
check("the new account can sign in") { post_form("/login", { "email" => email, "password" => password }).code == "302" }

puts "\n-- a second account for the second browser"
other_email = "other-#{Time.now.to_i}@example.com"
response = post_form("/signup", { "user" => { "name" => "Other Account", "email" => other_email, "password" => "a", "password_confirmation" => "a" } })
check("the second account is registered") { response.code == "302" }

puts "\n-- the table"
page = request(:get, "/users")
check("the table is rendered") { page.code == "200" && page.body.include?("users-table") }
check("the toolbar is above the table") { page.body.include?("id=\"block-selected\"") && page.body.include?("id=\"unblock-selected\"") && page.body.include?("id=\"delete-selected\"") }
check("the header checkbox has no label") { page.body.include?("id=\"select-all\"") && !page.body.match?(/for="select-all"/) }
check("the new account is in the table") { page.body.include?(email) }
check("the table is sorted by the last login time") { page.body.include?("Last login") }

other_id = id_of(page.body, other_email)
check("the other account was found") { !other_id.nil? }

puts "\n-- the second browser signs in"
OTHER.clear
post_form("/login", { "email" => other_email, "password" => "a" }, jar: OTHER, token_page: "/login")
check("the second account can reach the table") { request(:get, "/users", jar: OTHER).code == "200" }

puts "\n-- the toolbar blocks an account"
response = post_form("/users/block_users", { "user_ids" => [other_id] }, token_page: "/users")
check("the block action redirects to the table") { response.code == "302" }
page = request(:get, "/users")
check("the status of the account changed") { page.body.match?(/Blocked/) }

puts "\n-- a blocked account is sent back to the login form"
check("the blocked account cannot reach the table anymore") do
  response = request(:get, "/users", jar: OTHER)
  response.code == "302" && response["location"].to_s.end_with?("/login")
end
check("the blocked account cannot sign in") do
  response = post_form("/login", { "email" => other_email, "password" => "a" }, jar: {}, token_page: "/login")
  response.code == "422" && response.body.include?("blocked")
end

puts "\n-- the toolbar unblocks and deletes"
post_form("/users/unblock_users", { "user_ids" => [other_id] }, token_page: "/users")
before = request(:get, "/users").body.scan(/data-user-id=/).size
post_form("/users/delete_users", { "user_ids" => [other_id] }, token_page: "/users")
after = request(:get, "/users").body.scan(/data-user-id=/).size
check("the row was deleted") { after == before - 1 }

puts "\n-- a deleted account is sent back to the login form"
check("the deleted account cannot reach the table anymore") do
  response = request(:get, "/users", jar: OTHER)
  response.code == "302" && response["location"].to_s.end_with?("/login")
end
check("the deleted account can register again") do
  response = post_form("/signup", { "user" => { "name" => "Again", "email" => other_email, "password" => "a", "password_confirmation" => "a" } })
  response.code == "302"
end

puts "\n-- the assistant"
page = request(:get, "/users")
csrf = token_of(page.body, "csrf-token")
response = request(:post, "/api/v1/assistant/ask", body: { "question" => "How many users are blocked?" }, headers: { "X-CSRF-Token" => csrf })
body = JSON.parse(response.body)
check("the question is answered") { response.code == "200" && body["answer"].include?("user") }
check("the answer was produced by the API") { body["api_calls"].first["status"] == 200 }

response = request(:post, "/api/v1/assistant/command", body: { "command" => "select users with e-mails started with s or p" }, headers: { "X-CSRF-Token" => csrf })
body = JSON.parse(response.body)
select = body["ui_actions"].find { |action| action["type"] == "select_users" }
check("the bot selects the users") { !select.nil? && select["ids"].any? }

puts "\n=========================================================="
puts " #{PASSED.size} checks passed, #{FAILED.size} failed"
puts "=========================================================="
FAILED.each { |description| puts " FAILED: #{description}" }
exit(FAILED.empty? ? 0 : 1)

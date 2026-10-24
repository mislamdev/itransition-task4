# frozen_string_literal: true

# Checks the configuration of a platform deployment (Render).
#
# It boots the application the way a platform does it:
#   - the database comes from DATABASE_URL (not from the discrete variables),
#   - the secret key comes from SECRET_KEY_BASE (the master key is missing),
#   - the assets are served by the application itself,
#   - the proxy terminates the TLS (X-Forwarded-Proto: https).
#
# Usage: bundle exec ruby script/check_platform.rb

require "net/http"
require "uri"
require "json"

BASE = ENV.fetch("CHECK_BASE_URL", "http://127.0.0.1:3201")
SECRET = ENV.fetch("SECRET_KEY_BASE", "")

results = []

def check(results, description)
  ok = yield
  results << [description, ok]
  puts "  #{ok ? 'PASS' : 'FAIL'}  #{description}"
rescue StandardError => e
  results << [description, false]
  puts "  FAIL  #{description} (#{e.class}: #{e.message})"
end

puts "== The configuration of a platform deployment =="

check(results, "the application boots without the master key") do
  system("bundle exec rails runner -e production 'puts Rails.application.secret_key_base.length' > /tmp/secret_len.txt 2>/tmp/secret_err.txt")
  File.read("/tmp/secret_len.txt").to_i.positive?
end

check(results, "the secret comes from SECRET_KEY_BASE") do
  File.read("/tmp/secret_len.txt").to_i == SECRET.length
end

# NOTE: the important one - the url of the platform has to win over the
# discrete variables, otherwise the application connects to the local database.
check(results, "the database comes from DATABASE_URL") do
  system("bundle exec rails runner -e production 'puts ActiveRecord::Base.connection_db_config.configuration_hash[:database]' > /tmp/db_name.txt 2>/dev/null")
  expected = ENV.fetch("EXPECTED_DATABASE", "")
  !expected.empty? && File.read("/tmp/db_name.txt").strip == expected
end

check(results, "the health endpoint answers") do
  response = Net::HTTP.get_response(URI.parse("#{BASE}/up"))
  response.code == "200"
end

check(results, "the login page is rendered") do
  response = Net::HTTP.get_response(URI.parse("#{BASE}/login"))
  response.code == "200" && response.body.include?("login-form")
end

check(results, "the assets are served by the application") do
  response = Net::HTTP.get_response(URI.parse("#{BASE}/login"))
  href = response.body[/href="(\/assets\/application[^"]+\.css)"/, 1]
  raise "no stylesheet in the page" if href.nil?

  asset = Net::HTTP.get_response(URI.parse("#{BASE}#{href}"))
  raise "the stylesheet is not served (#{asset.code})" unless asset.code == "200"

  # NOTE: the tokens live in their own file - it has to be served as well.
  tokens = response.body[/href="(\/assets\/theme\/tokens[^"]+\.css)"/, 1]
  raise "no tokens in the page" if tokens.nil?

  token_asset = Net::HTTP.get_response(URI.parse("#{BASE}#{tokens}"))
  token_asset.code == "200" && token_asset.body.include?("--theme-primary")
end

check(results, "the proxy is trusted (the redirect uses https)") do
  uri = URI.parse("#{BASE}/users")
  request = Net::HTTP::Get.new(uri)
  request["X-Forwarded-Proto"] = "https"
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  response.code == "302" && response["location"].to_s.start_with?("https://")
end

failed = results.count { |(_description, ok)| !ok }
puts
puts " #{results.size - failed} checks passed, #{failed} failed"
exit(failed.zero? ? 0 : 1)

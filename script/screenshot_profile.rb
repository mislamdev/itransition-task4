# frozen_string_literal: true

# A screenshot of the dropdown of the profile - the sign out button lives
# inside it.
#
# Usage: bundle exec ruby script/screenshot_profile.rb http://127.0.0.1:3200

require "selenium-webdriver"
require "fileutils"

BASE_URL = (ARGV[0] || "http://127.0.0.1:3100").chomp("/")
EMAIL = ENV.fetch("SCREENSHOT_EMAIL", "ada@example.com")
PASSWORD = ENV.fetch("SCREENSHOT_PASSWORD", "demo")
OUTPUT = File.join(File.expand_path("..", __dir__), "tmp", "screenshots")

FileUtils.mkdir_p(OUTPUT)

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--headless=new")
options.add_argument("--window-size=1440,900")
options.add_argument("--hide-scrollbars")
options.add_argument("--no-sandbox")

driver = Selenium::WebDriver.for(:chrome, options: options)

begin
  driver.navigate.to("#{BASE_URL}/login")
  sleep 1
  driver.find_element(id: "login-form").find_element(name: "email").send_keys(EMAIL)
  driver.find_element(id: "login-form").find_element(name: "password").send_keys(PASSWORD)
  driver.execute_script("arguments[0].click();", driver.find_element(css: "input[type=submit]"))
  sleep 2

  # NOTE: open the dropdown of the profile.
  driver.execute_script("arguments[0].click();", driver.find_element(css: ".account-chip"))
  sleep 1

  path = File.join(OUTPUT, "10_profile_dropdown.png")
  driver.save_screenshot(path)
  puts "saved: #{path}"

  # NOTE: the sign out has to be inside the dropdown.
  sign_out = driver.find_elements(css: ".dropdown-menu .dropdown-item-danger")
  puts "sign out inside the dropdown: #{sign_out.any? ? 'yes' : 'NO'}"
ensure
  driver.quit
end

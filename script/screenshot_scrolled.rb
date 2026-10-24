# frozen_string_literal: true

# A screenshot of the table while the page is scrolled - it shows that the
# toolbar and the header of the table stay visible (they are sticky).
#
# Usage: bundle exec ruby script/screenshot_scrolled.rb http://127.0.0.1:3200

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

  # NOTE: scroll down, so that the sticky toolbar and the header of the table
  # are visible in the middle of the page.
  driver.execute_script("window.scrollTo(0, 900);")
  sleep 1

  path = File.join(OUTPUT, "15_table_scrolled.png")
  driver.save_screenshot(path)
  puts "saved: #{path}"
ensure
  driver.quit
end

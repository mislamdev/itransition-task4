# frozen_string_literal: true

# The visual check of the panel.
#
# IMPORTANT: the script drives a REAL browser (Chrome), signs in, and stores
# the screenshots of the important pages in tmp/screenshots. It is used to
# verify that the table, the toolbar and the forms look right - in a desktop
# and in a mobile resolution.
#
# Usage:
#   bin/rails server -p 3100          # in another terminal
#   bundle exec ruby script/screenshot.rb http://127.0.0.1:3100

require "selenium-webdriver"
require "fileutils"

# NOTE: the script can be started without Rails (it only needs the browser),
# therefore the root directory is resolved by hand.
ROOT = File.expand_path("..", __dir__)

BASE_URL = ARGV[0] || "http://127.0.0.1:3100"
EMAIL = ENV.fetch("SCREENSHOT_EMAIL", "ada@example.com")
PASSWORD = ENV.fetch("SCREENSHOT_PASSWORD", "demo")
OUTPUT = File.join(ROOT, "tmp", "screenshots")

FileUtils.mkdir_p(OUTPUT)

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--headless=new")
options.add_argument("--window-size=1440,900")
options.add_argument("--hide-scrollbars")
options.add_argument("--no-sandbox")
options.add_argument("--disable-gpu")

# Small helper: waits until the page is completely loaded.
def wait_for_page(driver, timeout = 10)
  deadline = Time.now + timeout
  sleep 0.2 while driver.execute_script("return document.readyState") != "complete" && Time.now < deadline
end

# Small function: takes a screenshot and prints where it was stored.
def shot(driver, name)
  path = File.join(OUTPUT, "#{name}.png")
  driver.save_screenshot(path)
  puts "saved: #{path}"
end

driver = Selenium::WebDriver.for(:chrome, options: options)

begin
  # ----- the login form ------------------------------------------------------
  driver.navigate.to("#{BASE_URL}/login")
  wait_for_page(driver)
  shot(driver, "01_login")

  # ----- sign in -------------------------------------------------------------
  driver.find_element(id: "login-form").find_element(name: "email").send_keys(EMAIL)
  driver.find_element(id: "login-form").find_element(name: "password").send_keys(PASSWORD)
  driver.find_element(css: "input[type=submit]").click
  wait_for_page(driver)
  sleep 1
  shot(driver, "02_users_table")

  # ----- the selection + the toolbar ----------------------------------------
  rows = driver.find_elements(css: "#users-table tbody tr[data-user-id]")
  rows.first(3).each { |row| row.find_element(css: ".row-checkbox").click }
  sleep 0.5
  shot(driver, "03_selection")

  # ----- the assistant --------------------------------------------------------
  driver.find_element(css: "[data-assistant-input]").send_keys("How many users are blocked?")
  driver.find_element(id: "assistant-run").click
  sleep 3
  shot(driver, "04_assistant_answer")

  # ----- the assistant page --------------------------------------------------
  driver.navigate.to("#{BASE_URL}/assistant")
  wait_for_page(driver)
  shot(driver, "05_assistant_page")

  # ----- the mobile resolution ----------------------------------------------
  mobile = Selenium::WebDriver::Chrome::Options.new
  mobile.add_argument("--headless=new")
  mobile.add_argument("--window-size=390,844")
  mobile.add_argument("--hide-scrollbars")
  mobile.add_argument("--no-sandbox")

  mobile_driver = Selenium::WebDriver.for(:chrome, options: mobile)
  begin
    mobile_driver.navigate.to("#{BASE_URL}/login")
    wait_for_page(mobile_driver)
    shot(mobile_driver, "06_login_mobile")

    mobile_driver.find_element(id: "login-form").find_element(name: "email").send_keys(EMAIL)
    mobile_driver.find_element(id: "login-form").find_element(name: "password").send_keys(PASSWORD)
    mobile_driver.find_element(css: "input[type=submit]").click
    wait_for_page(mobile_driver)
    sleep 1
    shot(mobile_driver, "07_users_table_mobile")
  ensure
    mobile_driver.quit
  end
ensure
  driver.quit
end

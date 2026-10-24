# frozen_string_literal: true

# The visual check of the new design.
#
# It drives a real browser (Chrome) and stores the screenshots of the pages in
# tmp/screenshots - the login form, the registration form, the table and the
# assistant, in a desktop and in a mobile resolution.
#
# Usage: bundle exec ruby script/screenshot.rb http://127.0.0.1:3200

require "selenium-webdriver"
require "fileutils"

BASE_URL = (ARGV[0] || "http://127.0.0.1:3100").chomp("/")
EMAIL = ENV.fetch("SCREENSHOT_EMAIL", "ada@example.com")
PASSWORD = ENV.fetch("SCREENSHOT_PASSWORD", "demo")
OUTPUT = File.join(File.expand_path("..", __dir__), "tmp", "screenshots")

FileUtils.mkdir_p(OUTPUT)

# Small function: waits until the page is completely loaded.
def wait_for_page(driver, timeout = 15)
  deadline = Time.now + timeout
  sleep 0.2 while driver.execute_script("return document.readyState") != "complete" && Time.now < deadline
end

# Small function: takes a screenshot and prints where it was stored.
def shot(driver, name)
  path = File.join(OUTPUT, "#{name}.png")
  driver.save_screenshot(path)
  puts "saved: #{path}"
end

# Small function: clicks an element (the tooltip of Bootstrap can cover an
# element, therefore the click is done with javascript).
def click(driver, element)
  driver.execute_script("arguments[0].click();", element)
  sleep 0.4
end

def build_options(width, height)
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--window-size=#{width},#{height}")
  options.add_argument("--hide-scrollbars")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options
end

def sign_in(driver, email, password)
  driver.navigate.to("#{BASE_URL}/login")
  wait_for_page(driver)
  driver.find_element(id: "login-form").find_element(name: "email").send_keys(email)
  driver.find_element(id: "login-form").find_element(name: "password").send_keys(password)
  click(driver, driver.find_element(css: "input[type=submit]"))
  wait_for_page(driver)
  sleep 1
end

puts "== Screenshots of #{BASE_URL} =="

# ----- the desktop -----------------------------------------------------------
driver = Selenium::WebDriver.for(:chrome, options: build_options(1440, 900))

begin
  driver.navigate.to("#{BASE_URL}/login")
  wait_for_page(driver)
  shot(driver, "01_login")

  driver.navigate.to("#{BASE_URL}/signup")
  wait_for_page(driver)
  shot(driver, "02_register")

  sign_in(driver, EMAIL, PASSWORD)
  shot(driver, "03_users_table")

  rows = driver.find_elements(css: "#users-table tbody tr[data-user-id]")
  click(driver, rows.first(3).map { |row| row.find_element(css: ".row-checkbox") }.first)
  sleep 0.5
  shot(driver, "04_selection")

  driver.find_element(css: "[data-assistant-input]").send_keys("How many users are blocked?")
  click(driver, driver.find_element(id: "assistant-run"))
  sleep 3
  shot(driver, "05_assistant_answer")

  driver.navigate.to("#{BASE_URL}/assistant")
  wait_for_page(driver)
  shot(driver, "06_assistant_page")
ensure
  driver.quit
end

# ----- the mobile ------------------------------------------------------------
mobile = Selenium::WebDriver.for(:chrome, options: build_options(390, 844))

begin
  mobile.navigate.to("#{BASE_URL}/login")
  wait_for_page(mobile)
  shot(mobile, "07_login_mobile")

  sign_in(mobile, EMAIL, PASSWORD)
  shot(mobile, "08_users_table_mobile")
ensure
  mobile.quit
end

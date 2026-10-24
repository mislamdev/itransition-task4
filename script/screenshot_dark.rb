# frozen_string_literal: true

# The visual check of the DARK theme.
#
# It signs in, switches the theme with the button in the navigation header and
# stores the screenshots of the pages in tmp/screenshots.
#
# Usage: bundle exec ruby script/screenshot_dark.rb http://127.0.0.1:3200

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

# Small function: clicks an element with javascript.
def click(driver, element)
  driver.execute_script("arguments[0].click();", element)
  sleep 0.6
end

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--headless=new")
options.add_argument("--window-size=1440,900")
options.add_argument("--hide-scrollbars")
options.add_argument("--no-sandbox")

driver = Selenium::WebDriver.for(:chrome, options: options)

begin
  puts "== The dark theme of #{BASE_URL} =="

  # ----- the sign in form in the dark theme -----------------------------------
  driver.navigate.to("#{BASE_URL}/login")
  wait_for_page(driver)

  # NOTE: the switch of the theme is on the sign in page as well.
  click(driver, driver.find_element(css: ".theme-toggle"))
  wait_for_page(driver)
  sleep 1

  dark = driver.execute_script("return document.documentElement.classList.contains('theme-dark')")
  puts "the dark theme is switched on: #{dark ? 'yes' : 'NO'}"
  shot(driver, "11_login_dark")

  # ----- the registration in the dark theme -----------------------------------
  driver.navigate.to("#{BASE_URL}/signup")
  wait_for_page(driver)
  shot(driver, "14_register_dark")

  # ----- sign in (the theme stays switched on) --------------------------------
  driver.navigate.to("#{BASE_URL}/login")
  wait_for_page(driver)
  driver.find_element(id: "login-form").find_element(name: "email").send_keys(EMAIL)
  driver.find_element(id: "login-form").find_element(name: "password").send_keys(PASSWORD)
  click(driver, driver.find_element(css: "input[type=submit]"))
  wait_for_page(driver)
  sleep 1

  shot(driver, "12_users_table_dark")

  # ----- the assistant in the dark theme --------------------------------------
  driver.find_element(css: "[data-assistant-input]").send_keys("How many users are blocked?")
  click(driver, driver.find_element(id: "assistant-run"))
  sleep 3
  shot(driver, "13_assistant_dark")

ensure
  driver.quit
end

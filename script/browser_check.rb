# frozen_string_literal: true

# The browser check of the toolbar.
#
# IMPORTANT: the script drives a REAL browser (Chrome). It selects a row,
# presses the buttons of the toolbar and checks that the server did what the
# button promised. It is the proof that the table, the selection and the
# toolbar work together - exactly like a user would use them.
#
# Usage:
#   bundle exec ruby script/browser_check.rb https://<public url>
#   SCREENSHOT_EMAIL=ada@example.com SCREENSHOT_PASSWORD=demo bundle exec ruby script/browser_check.rb

require "selenium-webdriver"
require "fileutils"

BASE_URL = (ARGV[0] || "http://127.0.0.1:3100").chomp("/")
EMAIL = ENV.fetch("SCREENSHOT_EMAIL", "ada@example.com")
PASSWORD = ENV.fetch("SCREENSHOT_PASSWORD", "demo")
OUTPUT = File.join(File.expand_path("..", __dir__), "tmp", "screenshots")

PASSED = []
FAILED = []

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

# Small function: waits until a condition is true.
#
# NOTE: the deployed application is reached through a tunnel - it needs a
# little more time than the local server.
def wait_until(timeout = 15)
  deadline = Time.now + timeout
  sleep 0.3 until yield || Time.now > deadline
  yield
end

# Small function: clicks an element.
#
# NOTE: the click is done with javascript, because the tooltip of Bootstrap
# can cover an element (the tooltip follows the mouse) and a "real" mouse
# click would then hit the tooltip instead of the button.
def click(driver, element)
  driver.execute_script("arguments[0].click();", element)
  sleep 0.4
end

# Small function: the first row that does NOT belong to the signed in account.
#
# IMPORTANT: the toolbar must not block the account that is signed in - the
# test would lock itself out.
def other_row(driver, own_email)
  driver.find_elements(css: "#users-table tbody tr[data-user-id]").find do |row|
    row.find_element(css: "td:nth-child(3)").text.strip != own_email
  end
end

# Small function: waits until the page is completely loaded.
def wait_for_page(driver, timeout = 15)
  deadline = Time.now + timeout
  sleep 0.2 while driver.execute_script("return document.readyState") != "complete" && Time.now < deadline
end

FileUtils.mkdir_p(OUTPUT)

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--headless=new")
options.add_argument("--window-size=1440,900")
options.add_argument("--hide-scrollbars")
options.add_argument("--no-sandbox")
options.add_argument("--disable-gpu")

driver = Selenium::WebDriver.for(:chrome, options: options)

begin
  puts "== Browser check of #{BASE_URL} =="

  # ----- sign in -------------------------------------------------------------
  driver.navigate.to("#{BASE_URL}/login")
  wait_for_page(driver)
  driver.find_element(id: "login-form").find_element(name: "email").send_keys(EMAIL)
  driver.find_element(id: "login-form").find_element(name: "password").send_keys(PASSWORD)
  click(driver, driver.find_element(css: "input[type=submit]"))
  wait_for_page(driver)
  sleep 1

  check("the sign in opens the user table") { driver.current_url.include?("/users") }
  check("the table is rendered") { driver.find_elements(css: "#users-table tbody tr[data-user-id]").any? }
  check("the toolbar is above the table") do
    driver.find_element(id: "block-selected") &&
      driver.find_element(id: "unblock-selected") &&
      driver.find_element(id: "delete-selected")
  end

  check("the filter is in the toolbar") { driver.find_element(css: ".toolbar-filter input[name='q']") }

  # ----- the selection -------------------------------------------------------
  row = other_row(driver, EMAIL)
  click(driver, row.find_element(css: ".row-checkbox"))
  sleep 0.5

  check("the selection is counted") { driver.find_element(id: "selection-count").text == "1" }
  check("the block button is enabled") { driver.find_element(id: "block-selected").enabled? }
  check("the delete button is enabled") { driver.find_element(id: "delete-selected").enabled? }

  # ----- the header checkbox -------------------------------------------------
  click(driver, driver.find_element(id: "select-all"))
  sleep 0.5
  selected = driver.find_elements(css: "#users-table tbody .row-checkbox").count { |c| c.selected? }
  total = driver.find_elements(css: "#users-table tbody tr[data-user-id]").size
  check("the header checkbox selects every row") { selected == total }

  click(driver, driver.find_element(id: "select-all"))
  sleep 0.5
  selected = driver.find_elements(css: "#users-table tbody .row-checkbox").count { |c| c.selected? }
  check("the header checkbox deselects every row") { selected.zero? }

  # ----- the block button ----------------------------------------------------
  row = other_row(driver, EMAIL)
  blocked_email = row.find_element(css: "td:nth-child(3)").text.strip
  click(driver, row.find_element(css: ".row-checkbox"))
  click(driver, driver.find_element(id: "block-selected"))
  wait_for_page(driver)
  sleep 1

  check("the block button shows the message") do
    driver.find_elements(css: ".alert-success").any? { |alert| alert.text.include?("blocked") }
  end
  check("the row is blocked now") do
    row = driver.find_elements(css: "#users-table tbody tr[data-user-id]").find do |item|
      item.find_element(css: "td:nth-child(3)").text.strip == blocked_email
    end
    row && row.find_element(css: ".status-blocked").text.include?("Blocked")
  end
  driver.save_screenshot(File.join(OUTPUT, "08_after_block.png"))

  # ----- the unblock button --------------------------------------------------
  row = other_row(driver, EMAIL)
  click(driver, row.find_element(css: ".row-checkbox"))
  check("the unblock button is enabled for a blocked row") { driver.find_element(id: "unblock-selected").enabled? }
  click(driver, driver.find_element(id: "unblock-selected"))
  wait_for_page(driver)
  sleep 1

  check("the unblock button shows the message") do
    driver.find_elements(css: ".alert-success").any? { |alert| alert.text.include?("unblocked") }
  end

  # ----- the assistant in the browser ---------------------------------------
  driver.find_element(css: "[data-assistant-input]").send_keys("How many users are blocked?")
  click(driver, driver.find_element(id: "assistant-run"))
  sleep 3

  check("the assistant answers the question") do
    driver.find_element(css: ".assistant-answer-text").text.include?("user")
  end
  driver.save_screenshot(File.join(OUTPUT, "09_assistant_in_browser.png"))

  # ----- the status message (the toast) --------------------------------------
  # NOTE: the message of the block action - it has to float in the top right
  # corner and it has to close itself.
  toast = driver.find_elements(css: ".app-toast")
  check("the status message is a toast") { toast.any? }

  if toast.any?
    # NOTE: the position of the toast - it floats in the top right corner.
    position = driver.execute_script(
      "var box = arguments[0].getBoundingClientRect();" \
      "return { x: box.x, y: box.y, width: box.width, right: box.right };",
      toast.first
    )
    check("the toast is in the top right corner") do
      position["right"] >= 1440 - 20 && position["y"] < 200
    end
    check("the toast closes itself") do
      disappeared = wait_until(15) { driver.find_elements(css: ".app-toast").empty? }
      disappeared
    end
  end
  driver.save_screenshot(File.join(OUTPUT, "11_toast_gone.png"))

  # ----- the live filter (the table is filtered WHILE typing) --------------
  before = driver.find_elements(css: "#users-table tbody tr[data-user-id]").size
  filter = driver.find_element(css: '.toolbar-search input[name="q"]')
  filter.clear
  filter.send_keys("shafi")

  # NOTE: the table is replaced by the answer of the server - the test waits
  # for the new table.
  filtered = wait_until do
    begin
      rows = driver.find_elements(css: "#users-table tbody tr[data-user-id]")
      rows.any? && rows.first.find_element(css: "td:nth-child(2)").text.include?("Shafi")
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      # NOTE: the table is replaced while the test reads it - the next round
      # reads the new table.
      false
    end
  end

  after = driver.find_elements(css: "#users-table tbody tr[data-user-id]").size
  check("the table is filtered while the user types") { after < before && after > 0 }
  # NOTE: the name is checked and not the e-mail - the edge of Cloudflare
  # replaces the e-mail in the DOM with "[email protected]" (it is shown
  # correctly on the screen, but the text of the element is the protected one).
  check("the filtered row is the right one") { filtered }
  check("the counters follow the filter") do
    driver.find_element(id: "stat-total").text.strip == after.to_s
  end
  check("the address bar shows the filter") { driver.current_url.include?("q=shafi") }

  # NOTE: the filter is cleared again, so that the table is complete. The
  # event is dispatched by hand - `clear` does not fire the "input" event.
  driver.execute_script(
    "arguments[0].value = ''; arguments[0].dispatchEvent(new Event('input', { bubbles: true }));", filter
  )
  complete = wait_until do
    driver.find_elements(css: "#users-table tbody tr[data-user-id]").size == before
  end
  check("the table is complete again") { complete }
  driver.save_screenshot(File.join(OUTPUT, "10_live_filter.png"))

  puts "\n=========================================================="
  puts " #{PASSED.size} checks passed, #{FAILED.size} failed"
  puts "=========================================================="
  FAILED.each { |description| puts " FAILED: #{description}" }
ensure
  driver.quit
end

exit(FAILED.empty? ? 0 : 1)

# frozen_string_literal: true

# The responsive check of the application.
#
# It opens the important pages in the four resolutions of the checklist
# (375, 768, 1024 and 1440 pixels) and stores the screenshots in
# tmp/screenshots/responsive.
#
# IMPORTANT: the script also reports whether the PAGE has a horizontal
# scrollbar - a wide table may scroll inside its own container, but the page
# itself must never scroll sideways.
#
# Usage: bundle exec ruby script/responsive_check.rb http://127.0.0.1:3200

require "selenium-webdriver"
require "fileutils"

BASE_URL = (ARGV[0] || "http://127.0.0.1:3100").chomp("/")
EMAIL = ENV.fetch("SCREENSHOT_EMAIL", "ada@example.com")
PASSWORD = ENV.fetch("SCREENSHOT_PASSWORD", "demo")
OUTPUT = File.join(File.expand_path("..", __dir__), "tmp", "screenshots", "responsive")

WIDTHS = [375, 768, 1024, 1440].freeze

FileUtils.mkdir_p(OUTPUT)

# Small function: waits until the page is completely loaded.
def wait_for_page(driver, timeout = 15)
  deadline = Time.now + timeout
  sleep 0.2 while driver.execute_script("return document.readyState") != "complete" && Time.now < deadline
end

# Small function: clicks an element with javascript.
def click(driver, element)
  driver.execute_script("arguments[0].click();", element)
  sleep 0.5
end

# Small function: the width of the page - it must never be bigger than the
# window (that would be a horizontal scrollbar of the page).
def page_width(driver)
  driver.execute_script("return document.documentElement.scrollWidth")
end

problems = []

WIDTHS.each do |width|
  height = width < 500 ? 812 : 900

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--window-size=#{width},#{height}")
  options.add_argument("--hide-scrollbars")
  options.add_argument("--no-sandbox")

  driver = Selenium::WebDriver.for(:chrome, options: options)

  begin
    # NOTE: Chrome does not accept a window smaller than 500 pixels - the real
    # viewport is set with the device emulation of the developer protocol.
    driver.execute_cdp("Emulation.setDeviceMetricsOverride",
                       width: width, height: height, deviceScaleFactor: 1, mobile: width < 500)

    driver.navigate.to("#{BASE_URL}/login")
    wait_for_page(driver)
    driver.save_screenshot(File.join(OUTPUT, "#{width}_login.png"))

    driver.find_element(id: "login-form").find_element(name: "email").send_keys(EMAIL)
    driver.find_element(id: "login-form").find_element(name: "password").send_keys(PASSWORD)
    click(driver, driver.find_element(css: "input[type=submit]"))
    wait_for_page(driver)
    sleep 1

    driver.save_screenshot(File.join(OUTPUT, "#{width}_users.png"))

    scroll = page_width(driver)
    viewport = driver.execute_script("return window.innerWidth")
    if scroll > viewport + 1
      problems << "#{width}px: the page scrolls sideways (#{scroll}px in a viewport of #{viewport}px)"
    end

    puts "#{width}px: the viewport is #{viewport}px, the page is #{scroll}px wide"
  ensure
    driver.quit
  end
end

puts
if problems.empty?
  puts "OK - no page scrolls sideways."
else
  puts "PROBLEMS:"
  problems.each { |problem| puts " - #{problem}" }
end

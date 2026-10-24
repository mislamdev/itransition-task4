# frozen_string_literal: true

# Small helper: shows whether the asset pipeline finds the files of the theme.
#
# It is useful when a stylesheet is not found ("The asset '...' was not found
# in the load path") - the reason is usually a stale manifest of a previous
# `assets:precompile` (the manifest is only used in production, see
# config/environments/production.rb).
#
# Usage: bin/rails runner script/check_assets.rb

assembly = Rails.application.assets

puts "theme/tokens.css           -> #{assembly.load_path.find("theme/tokens.css") ? "found" : "MISSING"}"
puts "theme/bootstrap-theme.css  -> #{assembly.load_path.find("theme/bootstrap-theme.css") ? "found" : "MISSING"}"
puts "theme/components.css       -> #{assembly.load_path.find("theme/components.css") ? "found" : "MISSING"}"
puts "application.css            -> #{assembly.load_path.find("application.css") ? "found" : "MISSING"}"
puts "bootstrap.min.css          -> #{assembly.load_path.find("bootstrap.min.css") ? "found" : "MISSING"}"
puts "bootstrap-icons.min.css    -> #{assembly.load_path.find("bootstrap-icons.min.css") ? "found" : "MISSING"}"

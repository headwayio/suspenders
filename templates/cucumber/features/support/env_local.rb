require 'simplecov'
SimpleCov.coverage_dir 'coverage/cucumber'
SimpleCov.start 'rails'

require 'capybara/poltergeist'
require 'capybara/dsl'

require 'site_prism'
SitePrism.use_implicit_waits = true

require 'email_spec'
require 'email_spec/cucumber'

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :poltergeist
Capybara.asset_host = 'http://localhost:3000'

Capybara.register_driver :poltergeist_debug do |app|
  Capybara::Poltergeist::Driver.new(app, inspector: true)
end

Before('@javascript_debug') do
  Capybara.current_driver = :poltergeist_debug
end
After('@javascript_debug') do
  Capybara.use_default_driver
end

Before('@rack') do
  Capybara.current_driver = :rack_test
end
After('@rack') do
  Capybara.use_default_driver
end

# two ways to debug cukes
#
# 1) with a tag
After('@debug') do |scenario|
  save_and_open_page if scenario.failed? # rubocop:disable Lint/Debugger
end

# 2) with an env var (more useful for starting this way with guard)
After do |scenario|
  # rubocop:disable Lint/Debugger
  save_and_open_page if scenario.failed? && (ENV['DEBUG'] == 'open')
  # rubocop:enable Lint/Debugger
end

Before('@browser') do
  Capybara.current_driver = :selenium
end
After('@browser') do
  Capybara.use_default_driver
end

# Update cuke steps html file with step definitions
# Run the script each time before the suite starts
`ruby #{Rails.root}/features/support/cuke_steps.rb`

Chronic.time_class = Time.zone

# Autoload page objects.
ActiveSupport::Dependencies.autoload_paths << Rails.root.join('features', 'pages') # rubocop:disable Metrics/LineLength

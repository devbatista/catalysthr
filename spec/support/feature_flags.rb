# Flipper raises in tests for flags nobody declared (config/initializers/flipper.rb),
# and its test helper empties the in-memory flags before each example. The declared
# flags are created again, disabled; a test turns on what it needs.
RSpec.configure do |config|
  config.before { FeatureFlags.declare }
end

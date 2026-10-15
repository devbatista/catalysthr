# Rails loads routes lazily outside production, on the first request. Devise registers
# its Warden strategies when the routes load, so a suite whose first request is a
# sign-in would fail it. Production loads routes at boot (eager_load).
RSpec.configure do |config|
  config.before(:suite) { Rails.application.reload_routes_unless_loaded }
end

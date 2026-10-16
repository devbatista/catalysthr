# Simulated writes of the impersonate (RN-02-084, D-186): the action runs inside a
# transaction that is rolled back at the end, and nothing leaves the system meanwhile.
# Jobs are not enqueued, e-mails are not delivered and any HTTP call is refused
# (config/initializers/simulation.rb), which also covers uploads to S3 and the external
# services (RN-02-085).
module Simulation
  # Raised by an HTTP call attempted during a simulated write.
  class ExternalCallBlocked < StandardError; end

  module_function

  def active?
    Current.simulation == true
  end

  def run
    Current.simulation = true
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  ensure
    Current.simulation = false
  end
end

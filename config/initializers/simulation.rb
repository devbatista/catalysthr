# Nothing leaves the system during an impersonate simulation (RN-02-084, RN-02-085).
# The guards live here, outside the reloadable code, and ask Simulation at each call.
require "net/http"

module SimulationGuards
  # Refuses every Net::HTTP request, which covers S3 and the external services.
  module NetHttp
    def request(...)
      raise Simulation::ExternalCallBlocked, "HTTP call refused during an impersonate simulation" if Simulation.active?

      super
    end
  end

  # Drops the e-mails delivered right away.
  class MailInterceptor
    def self.delivering_email(message)
      message.perform_deliveries = false if Simulation.active?
    end
  end
end

Net::HTTP.prepend(SimulationGuards::NetHttp)

ActiveSupport.on_load(:action_mailer) do
  ActionMailer::Base.register_interceptor(SimulationGuards::MailInterceptor)
end

# Jobs, including the e-mails sent with deliver_later, are not enqueued.
ActiveSupport.on_load(:active_job) do
  around_enqueue do |_job, block|
    block.call unless Simulation.active?
  end
end

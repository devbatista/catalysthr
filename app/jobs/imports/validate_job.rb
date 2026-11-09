module Imports
  # Reads and validates a file sent to an import (spec 18, section 8), on the imports queue,
  # with low concurrency so it never competes with the time tracking (P-18-26). The company
  # comes with the job (acts_as_tenant).
  class ValidateJob < ApplicationJob
    queue_as :imports

    def perform(import)
      Validation.call(import)
    end
  end
end

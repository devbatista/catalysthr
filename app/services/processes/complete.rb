module Processes
  # Ends a process whose required items are all resolved (RN-06-053, P-06-16): by the HR,
  # or by the system with the automatic end. Cancelling asks for a reason (section 5).
  module Complete
    module_function

    def call(instance, by:)
      instance.with_lock do
        return false unless instance.ready_to_complete?

        instance.update!(status: "completed", completed_at: Time.current, completed_by: by)
        Events.record(instance, "completed", by: by)
      end
      true
    end

    def cancel(instance, by:, reason:)
      instance.with_lock do
        return false unless instance.open?

        instance.assign_attributes(status: "cancelled", cancelled_at: Time.current, cancelled_by: by, cancel_reason: reason)
        return false unless instance.save

        Events.record(instance, "cancelled", by: by, reason: instance.cancel_reason)
        # Answers never applied have no reason to stay (D-649).
        ProcessFormResponse.discard(instance.items.select(:id))
      end
      true
    end
  end
end

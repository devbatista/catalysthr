module Processes
  # After an item is resolved, frees the items whose dependencies are all resolved
  # (RN-06-040, CA-06-004) and tells who answers for them (spec 15). With the automatic
  # end, closes the process once every required item is resolved (RN-06-053, D-641).
  # Runs again without repeating: a freed item is no longer blocked.
  class UnblockItemsJob < ApplicationJob
    queue_as :default

    def perform(item)
      instance = item.instance
      ActsAsTenant.with_tenant(instance.company) do
        return unless instance.open?

        freed = Unblock.call(instance)
        Notices.assigned(freed)
        Complete.call(instance, by: nil) if instance.completes_automatic? && instance.reload.ready_to_complete?
      end
    end
  end
end

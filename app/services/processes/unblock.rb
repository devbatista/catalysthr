module Processes
  # Frees the blocked items whose dependencies are all resolved: done, approved, received
  # or skipped (RN-06-040, RN-06-052). Returns the freed items.
  module Unblock
    module_function

    def call(instance)
      items = instance.items.includes(:depends_on).to_a
      items.select { |item| item.blocked? && item.depends_on.all?(&:resolved?) }.each do |item|
        item.update!(status: "pending")
        Events.record(instance, "item_unblocked", by: nil, item: item, title: item.title)
      end
    end
  end
end

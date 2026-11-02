module Processes
  # A reference date changed, such as the start postponed by the admission (spec 07): the
  # dates of the items not yet resolved follow it, except those the HR set by hand
  # (RN-06-027, P-06-08, CA-06-007).
  module ChangeAnchors
    module_function

    def call(instance, anchors, by:)
      changed = anchors.to_h.transform_keys(&:to_s).transform_values { |date| date&.to_date&.iso8601 }
        .slice(*ProcessTemplateItemDefinition::ANCHORS.fetch(instance.kind))
        .reject { |key, value| instance.anchor_dates[key] == value }
      return [] if changed.empty? || !instance.open?

      instance.transaction do
        instance.update!(anchor_dates: instance.anchor_dates.merge(changed))
        instance.items.select { |item| !item.resolved? && !item.due_manually_set && changed.key?(item.due_anchor) }.each do |item|
          due = Deadline.for(instance, item.due_anchor, item.due_offset_days, item.due_business_days)
          next if due == item.due_on

          Events.record(instance, "due_recalculated", by: by, item: item, title: item.title, from: item.due_on&.iso8601,
            to: due&.iso8601)
          item.update!(due_on: due, overdue_notified_on: nil)
        end
      end
    end
  end
end

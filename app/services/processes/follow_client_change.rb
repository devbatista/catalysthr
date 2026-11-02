module Processes
  # The employment moved to another allocation client: the open items of the
  # `client_manager` role go to the new client's managers, since the old ones lose access
  # (RN-06-036, RN-04-095, P-06-21, CA-06-010). Without managers there, they go to the HR,
  # with the alert (RN-06-022). The other changes only warn the HR on the process's page.
  # Runs again without repeating. Read inside the company.
  module FollowClientChange
    module_function

    def call(employment, by: nil)
      ProcessInstance.open.where(subject: employment).find_each do |instance|
        items = instance.items.select { |item| item.open? && item.responsible_role == "client_manager" }
        next if items.empty?

        starter = Membership.with_access.find_by(organization: instance.company, user_id: instance.started_by_id)
        assignment = Responsibles.new(company: instance.company, employment: employment, kind: instance.kind, starter: starter)
          .for("client_manager")
        moved = items.reject { |item| item.responsible_membership_ids.sort == assignment.membership_ids.sort }
        moved.each do |item|
          item.update!(responsible_membership_ids: assignment.membership_ids, responsible_fallback: assignment.fallback)
          Events.record(instance, "client_changed", by: by, item: item, title: item.title)
        end
        Notices.assigned(moved.select(&:pending?))
      end
    end
  end
end

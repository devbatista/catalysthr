module Processes
  # The notices of the processes, as in spec 15's catalog (D-641): the item assigned to
  # the client's manager, and the item past its date to who answers for it and to the
  # process's HR (RN-06-028). The person's notices come with the portal (spec 16). Only the
  # item's title, the person's name and the date (RN-15-005).
  module Notices
    module_function

    OVERDUE_ROLES = %w[manager upper_manager client_manager].freeze

    def assigned(items)
      items.each do |item|
        Membership.where(id: item.responsible_membership_ids).with_role("client_manager").includes(:user).each do |membership|
          notify("processes.task_assigned", item, membership)
        end
      end
    end

    def overdue(item)
      instance = item.instance
      people = OVERDUE_ROLES.include?(item.responsible_role) ? item.responsibles.with_access.includes(:user).to_a : []
      people += HrScope.new(instance.company).memberships_for(unit_id: instance.unit_id, kind: instance.kind)
      people.uniq.each { |membership| notify("processes.task_overdue", item, membership) }
    end

    def notify(code, item, membership)
      instance = item.instance
      Notifications.notify!(code, user: membership.user, membership: membership, company: instance.company, subject: item,
        path: "/processes/#{instance.id}", item: item.title, person: instance.subject.worker_profile.display_name,
        due: item.due_on ? I18n.l(item.due_on) : I18n.t("processes.no_due"))
    end
    private_class_method :notify
  end
end

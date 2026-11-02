module Processes
  # Every morning, tells who answers for each item past its date and the process's HR, once
  # per item (RN-06-028, P-06-09). Being late blocks nothing; the screens show it from the
  # date. A new date lets it be told again (ChangeAnchors).
  class OverdueItemsJob < ApplicationJob
    queue_as :default

    def perform
      company_ids = CrossCompany.scope(ProcessItem, Company.all).where(status: %w[blocked pending], overdue_notified_on: nil)
        .where(due_on: ...Date.current).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { notify_company }
      end
    end

    private

    def notify_company
      ProcessItem.where(status: %w[blocked pending], overdue_notified_on: nil).where(due_on: ...Date.current)
        .joins(:instance).merge(ProcessInstance.open).includes(instance: [ :unit, { subject: :worker_profile } ]).find_each do |item|
        next unless item.overdue?

        Notices.overdue(item)
        item.update!(overdue_notified_on: item.instance.today)
      end
    end
  end
end

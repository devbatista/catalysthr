module Processes
  # The admission's forward to the company's accounting firm (RN-06-065, RN-07-070, D-651,
  # D-652): the HR sends it, the firm reads what the item chose and confirms. The firm reads
  # only what it received, while the link is active and the admission isn't cancelled.
  module FirmForward
    Row = Data.define(:item, :company, :person, :started_on)

    STATUSES = %w[sent received].freeze
    RESULT_KEYS = %w[accounting_firm_id accounting_firm_name sent_at].freeze
    MODULE_CODE = "admissao".freeze
    LIST_LIMIT = 200

    module_function

    # The company's firm (D-171, D-589). Read inside the company.
    def linked_firm(company)
      AccountingFirmCompany.find_by(company: company, status: "active")&.accounting_firm
    end

    # What the firm received from the companies given by the area, each read inside its
    # company. Waiting first, then the newest.
    def rows(firm, companies)
      items = items_of(firm, companies).order(Arel.sql("process_items.status = 'received', process_items.result->>'sent_at' DESC"))
        .limit(LIST_LIMIT).to_a
      names = companies.index_by(&:id)
      built = items.group_by(&:company_id).flat_map do |company_id, group|
        ActsAsTenant.with_tenant(names.fetch(company_id)) { group.map { |item| row(item, names.fetch(company_id)) } }
      end.index_by { |row| row.item.id }
      items.map { |item| built.fetch(item.id) }
    end

    # One forward of the firm, to open with the company as the tenant. Raises not found
    # for anything else (RN-03-006).
    def find(firm, companies, id)
      items_of(firm, companies).find(id)
    end

    def items_of(firm, companies)
      readable = companies.select { |company| company.contract_modules.releasable.include?(MODULE_CODE) }
      scope = Company.where(id: readable.map(&:id))
      instances = CrossCompany.scope(ProcessInstance, scope).where(kind: "admission", status: %w[open completed])
      CrossCompany.scope(ProcessItem, scope).forward.where(status: STATUSES, process_instance_id: instances.select(:id))
        .where("process_items.result->>'accounting_firm_id' = ?", firm.id)
    end

    # The documents approved in this admission and the signed contract, never health
    # (P-03-18, D-652). Read inside the company.
    def documents(item)
      instance = item.instance
      approved = instance.items.document.approved.filter_map { |document_item| document_item.result["document_id"] }
      signed = GeneratedDocument.where(employment_id: instance.subject_id).where.not(signed_document_id: nil).pluck(:signed_document_id)
      Document.kept.where(id: approved + signed).where.not(current_version_id: nil).joins(:document_type)
        .where(document_types: { category: DocumentCategory.readable(health: false, pay: true) })
    end

    # Only the title of the company's process and the person's name (RN-15-005).
    def notify(item)
      instance = item.instance
      firm = AccountingFirm.find(item.result.fetch("accounting_firm_id"))
      Membership.with_access.where(organization: firm).includes(:user).each do |membership|
        Notifications.notify!("accounting.admission_forwarded", user: membership.user, membership: membership, company: item.company,
          brand: item.company.subdomain_brand, area: "panel", subject: item, dedup_key: "firm_forward/#{item.id}/#{item.result["sent_at"]}",
          path: "/firm/forwards/#{item.id}", person: instance.subject.worker_profile.display_name, company_name: item.company.name)
      end
    end

    # The link ended: what wasn't confirmed goes back to the HR (RN-02-073, D-652).
    def return_to_hr(link, by:)
      ActsAsTenant.with_tenant(link.company) do
        ProcessItem.forward.sent.where("result->>'accounting_firm_id' = ?", link.accounting_firm_id).find_each do |item|
          ItemActions.new(item, by: by).return_from_firm
        end
      end
    end

    def row(item, company)
      employment = item.instance.subject
      Row.new(item: item, company: company, person: employment.worker_profile.display_name, started_on: employment.started_on)
    end
    private_class_method :row
  end
end

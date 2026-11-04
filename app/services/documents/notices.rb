module Documents
  # The documents' notices in spec 15's catalog (D-643). An expiring document goes to the
  # unit's HR who reads it, with the link to it, and to the department's managers with the
  # text only, never the file (P-08-11, CA-08-004). Only the type, the person's name and the
  # date (RN-15-005).
  module Notices
    module_function

    def expiring(document)
      profile = document.worker_profile
      company = document.company
      params = { document: document.document_type.name, person: profile.display_name, date: I18n.l(document.expires_on) }
      key = "expiring/#{document.id}/#{document.expires_on.iso8601}"

      Processes::HrScope.new(company).memberships_for(unit_id: profile.current_unit&.id, modul: "documentos").each do |membership|
        next unless Ability.new(membership.user, area: :panel, company: company).can?(:read, document)

        Notifications.notify!("documents.hr_expiring", user: membership.user, membership: membership, company: company,
          subject: document, dedup_key: key, path: "/documents/#{document.id}", **params)
      end
      employee("documents.expiring", document, dedup_key: key, date: params[:date])
      managers(profile).each do |membership|
        Notifications.notify!("documents.team_expiring", user: membership.user, membership: membership, company: company,
          subject: document, dedup_key: key, path: "/employees/#{profile.id}", **params)
      end
    end

    # A version the employee sent, to the unit's HR who reviews it (spec 15, D-645), once
    # per version.
    def review_pending(document)
      version = document.latest_version
      profile = document.worker_profile
      company = document.company
      return unless version

      Processes::HrScope.new(company).memberships_for(unit_id: profile.current_unit&.id, modul: "documentos").each do |membership|
        next unless Ability.new(membership.user, area: :panel, company: company).can?(:review, document)

        Notifications.notify!("documents.review_pending", user: membership.user, membership: membership, company: company,
          subject: version, path: "/documents/#{document.id}?version_id=#{version.id}", document: document.document_type.name,
          person: profile.display_name)
      end
    end

    # The employee's notices (spec 15, D-645): a document asked, a correction, an expiring
    # one and an acknowledgment waiting, each with the portal's page. Only for who already
    # has access, never with the document's content (RN-15-005).
    def employee(code, document, subject: document, **params)
      profile = document.worker_profile
      membership = profile.membership
      return unless membership&.active?

      Notifications.notify!(code, user: profile.user, membership: membership, company: document.company, subject: subject,
        path: "/portal/documents/#{document.id}", document: document.document_type.name, **params)
    end

    def managers(profile)
      department = profile.current_employment&.effective_revision&.department
      department ? department.managers.with_access.includes(:user).to_a : []
    end
    private_class_method :managers
  end
end

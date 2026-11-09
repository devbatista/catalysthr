module Dashboards
  # Writes the HR panel's "Atividade recente" (RN-17-011, D-657, D-658): in phase 2, the
  # documents sent and the admissions forwarded to the accounting firm. A document of the
  # health category goes without its type's name, which already says something about health
  # (D-658), and links to the folder, which asks for the password.
  module Activity
    NAMELESS_CATEGORIES = %w[health].freeze

    module_function

    # A new version of a document, sent by the HR or by the employee (RN-08-010, RN-08-012).
    def document_sent(document, by:)
      profile = document.worker_profile
      person = profile.display_name
      name = NAMELESS_CATEGORIES.include?(document.category) ? I18n.t("dashboards.activity.a_document") : document.document_type.name
      text = if by && by == profile.user
        I18n.t("dashboards.activity.document_sent_by_person", person: person, document: name)
      else
        I18n.t("dashboards.activity.document_sent", actor: by&.name, person: person, document: name)
      end
      url = if NAMELESS_CATEGORIES.include?(document.category)
        routes.employee_documents_path(profile, category: document.category)
      else
        routes.document_path(document)
      end
      ActivityEvent.record("document_sent", employment: profile.current_employment, module_code: module_of(document), text: text,
        actor: by, url: url)
    end

    # The admission's forward sent to the company's accounting firm (RN-06-065, D-652).
    def admission_forwarded(item, by:)
      employment = item.instance.employment
      admission = Admission.find_by(process_instance_id: item.instance.id)
      text = I18n.t("dashboards.activity.admission_forwarded", actor: by.name, person: employment.worker_profile.display_name,
        firm: item.result["accounting_firm_name"])
      ActivityEvent.record("admission_forwarded", employment: employment, module_code: "admissao", text: text, actor: by,
        url: admission && routes.admission_path(admission))
    end

    # A document asked by an admission is the admission's (D-650); the others, the folder's.
    def module_of(document)
      document.source_ref.is_a?(ProcessItem) && document.source_ref.instance.admission? ? "admissao" : "documentos"
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end

# The documents' screens (spec 08, D-642): the types, the folder, a document with its
# versions and the review queue.
module DocumentsHelper
  VERSION_PILLS = { "submitted" => "pill-info", "scanning" => "pill-info", "ai_processing" => "pill-info",
    "ai_failed" => "pill-warn", "awaiting_review" => "pill-warn", "approved" => "pill-ok",
    "correction_requested" => "pill-bad", "replaced" => "pill-mute", "rejected_by_scan" => "pill-bad" }.freeze

  # "Não vence", "Validade do documento", "A cada 12 meses" or "Aceito até 90 dias".
  def document_type_expiration(type)
    case type.expiration_rule
    when "periodicity" then t("document_types.expiration_summary.periodicity", count: type.expiration_months)
    when "age" then t("document_types.expiration_summary.age", count: type.max_age_days)
    else t("document_types.expiration_rules.#{type.expiration_rule}")
    end
  end

  def document_type_flags(type)
    flags = []
    flags << tag.span(t("document_types.flags.sensitive"), class: "pill pill-warn") if type.sensitive?
    flags << tag.span(t("document_types.flags.internal"), class: "pill pill-mute") if type.internal
    flags << tag.span(t("document_types.flags.acknowledgment"), class: "pill pill-info") if type.requires_acknowledgment
    flags << tag.span(t("document_types.flags.files", count: type.max_files), class: "pill pill-mute") if type.max_files > 1
    safe_join(flags)
  end

  def document_version_pill(version)
    return tag.span(t("documents.no_version"), class: "pill pill-mute") unless version

    tag.span(t("documents.version_statuses.#{version.status}"), class: "pill #{VERSION_PILLS.fetch(version.status)}")
  end

  # "RG", or "Certidão de nascimento · Pedro" for a dependent's, or with the account's last
  # digits (D-604).
  def document_title(document)
    about = document.dependent&.name || (bank_account_summary(document.bank_account) if document.bank_account)
    [ document.document_type.name, about ].compact.join(" · ")
  end

  # The reason of a correction, with the note of "Outro" (P-08-09).
  def correction_text(version)
    reason = t("documents.correction_reasons.#{version.correction_reason}")
    version.correction_note ? "#{reason}: #{version.correction_note}" : reason
  end

  # On the record, a dependent's certificate or an account's proof (RN-04-043, P-04-17,
  # D-604): the documents already sent, or the link to send one.
  def linked_document_link(profile, documents, dependent: nil, bank_account: nil)
    mine = documents.select { |document| dependent ? document.dependent_id == dependent.id : document.bank_account_id == bank_account.id }
    links = mine.map { |document| link_to(document.document_type.name, document_path(document), class: "link-button text-sm") }
    if can?(:upload, Document) && (dependent || bank_account).active?
      label = t(dependent ? "documents.linked.send_certificate" : "documents.linked.send_proof")
      links << link_to(label, new_employee_document_path(profile, dependent_id: dependent&.id, bank_account_id: bank_account&.id),
        class: "link-button text-sm")
    end
    safe_join(links, " · ")
  end

  def version_upload_text(version)
    t("documents.uploaded", number: version.number, date: l(version.uploaded_at, format: "%d/%m/%Y %H:%M"), name: version.uploaded_by.name)
  end
end

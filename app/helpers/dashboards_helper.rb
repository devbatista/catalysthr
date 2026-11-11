# The HR panel's texts (spec 17, D-658).
module DashboardsHelper
  # "CNH · Marcos Teles" or "Fim da experiência · Ana Lima", as in the prototype.
  def expiration_label(row)
    "#{expiration_title(row)} · #{expiration_owner(row)}"
  end

  # "CNH", "Fim da experiência" or "Certificado digital A1" (D-673).
  def expiration_title(row)
    case row.kind
    when :document then document_title(row.record)
    when :certificate then t("dashboards.hr.certificate")
    else t("dashboards.hr.experience_end")
    end
  end

  # The person, or the company for its certificate.
  def expiration_owner(row)
    row.person ? row.person.display_name : Current.company&.name
  end

  # Where an expiration opens: the document, the person's employment or the certificate.
  def expiration_path(row)
    case row.kind
    when :document then document_path(row.record)
    when :certificate then employer_certificate_path
    else employee_path(row.person)
    end
  end
end

# The HR panel's texts (spec 17, D-658).
module DashboardsHelper
  # "CNH · Marcos Teles" or "Fim da experiência · Ana Lima", as in the prototype.
  def expiration_label(row)
    what = row.kind == :document ? document_title(row.record) : t("dashboards.hr.experience_end")
    "#{what} · #{row.person.display_name}"
  end

  # Where an expiration opens: the document, or the person's employment.
  def expiration_path(row)
    row.kind == :document ? document_path(row.record) : employee_path(row.person)
  end
end

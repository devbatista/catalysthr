# Existing companies: the CNPJ root becomes the document, and the full CNPJ goes to the
# headquarters unit every company has (RN-04-001, RN-04-010, D-600). Idempotent.
class BackfillCompanyDocumentsAndHeadquarters < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationCompany < ActiveRecord::Base
    self.table_name = "companies"
    encrypts :document, deterministic: true
  end

  class MigrationUnit < ActiveRecord::Base
    self.table_name = "units"
  end

  def up
    MigrationCompany.where(document: nil).where.not(cnpj: nil).find_each do |company|
      company.update_columns(employer_type: "company", document: company.cnpj[0, 8])
    end

    MigrationCompany.find_each do |company|
      next if MigrationUnit.exists?(company_id: company.id, headquarters: true)

      MigrationUnit.create!(company_id: company.id, name: "Matriz", headquarters: true,
        registration_type: company.cnpj ? "cnpj" : nil, registration_number: company.cnpj)
    end
  end

  def down
  end
end

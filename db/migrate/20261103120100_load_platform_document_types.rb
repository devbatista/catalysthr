# The first platform document types (spec 08, RN-08-001, D-642): a short list across the
# categories, without the AI's extraction until spec 14. The team changes them in the
# admin afterwards. Idempotent: a code already there is left alone.
class LoadPlatformDocumentTypes < ActiveRecord::Migration[8.1]
  class MigrationDocumentType < ActiveRecord::Base
    self.table_name = "document_types"
  end

  TYPES = [
    { code: "rg", name: "RG", category: "personal", max_files: 2 },
    { code: "cpf", name: "CPF", category: "personal", max_files: 2 },
    { code: "cnh", name: "CNH", category: "personal", max_files: 2, expiration_rule: "document_date" },
    { code: "voter_id", name: "Título de eleitor", category: "personal", max_files: 2 },
    { code: "military_certificate", name: "Certificado de reservista", category: "personal", max_files: 2 },
    { code: "proof_of_address", name: "Comprovante de residência", category: "personal", expiration_rule: "age", max_age_days: 90 },
    { code: "birth_certificate", name: "Certidão de nascimento", category: "personal", max_files: 2 },
    { code: "marriage_certificate", name: "Certidão de casamento", category: "personal", max_files: 2 },
    { code: "photo", name: "Foto 3x4", category: "personal" },
    { code: "ctps", name: "Carteira de trabalho (CTPS)", category: "admission", max_files: 5 },
    { code: "pis", name: "Comprovante do PIS", category: "admission" },
    { code: "education_certificate", name: "Comprovante de escolaridade", category: "admission", max_files: 2 },
    { code: "aso_admission", name: "ASO admissional", category: "health", max_files: 2 },
    { code: "aso_periodic", name: "ASO periódico", category: "health", max_files: 2, expiration_rule: "periodicity", expiration_months: 12 },
    { code: "medical_certificate", name: "Atestado médico", category: "health", max_files: 2 },
    { code: "dependent_birth_certificate", name: "Certidão de nascimento do dependente", category: "dependents", max_files: 2 },
    { code: "dependent_cpf", name: "CPF do dependente", category: "dependents", max_files: 2 },
    { code: "school_statement", name: "Declaração escolar", category: "statements" },
    { code: "bank_account_proof", name: "Comprovante da conta bancária", category: "payroll" }
  ].freeze

  def up
    rows = TYPES.map do |type|
      { expiration_rule: "none", max_files: 1, expiration_months: nil, max_age_days: nil }.merge(type)
    end
    MigrationDocumentType.insert_all(rows, unique_by: :index_document_types_platform_code, record_timestamps: true)
  end

  def down
  end
end

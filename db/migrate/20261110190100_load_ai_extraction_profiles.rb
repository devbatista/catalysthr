# The extraction profile of the first platform types (spec 14, RN-14-021, D-670). The
# dependents' documents stay without one: their fields are compared with the dependent, which
# comes later. The team changes the profile in the admin. Idempotent: a type that already has
# one is left alone.
class LoadAiExtractionProfiles < ActiveRecord::Migration[8.1]
  class MigrationDocumentType < ActiveRecord::Base
    self.table_name = "document_types"
  end

  PROFILES = {
    "rg" => "rg", "cpf" => "cpf", "cnh" => "cnh", "ctps" => "ctps_pis", "pis" => "ctps_pis",
    "proof_of_address" => "proof_of_address", "birth_certificate" => "certificate", "marriage_certificate" => "certificate",
    "aso_admission" => "aso", "aso_periodic" => "aso", "medical_certificate" => "medical_certificate"
  }.freeze

  def up
    PROFILES.each do |code, profile|
      MigrationDocumentType.where(company_id: nil, code: code, ai_extraction_profile: nil).update_all(ai_extraction_profile: profile)
    end
  end

  def down; end
end

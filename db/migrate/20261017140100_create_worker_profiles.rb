# The person's record in a company, one per company membership (RN-04-040 to RN-04-042,
# P-04-01, D-209), by the eSocial groups of the worker's data (D-206). List fields keep
# the system's own values; the eSocial codes come with spec 13 (D-602). Personal
# documents and health data are encrypted, so their columns are text (D-086).
class CreateWorkerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_profiles do |t|
      t.references :company, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true, index: { unique: true }

      # Identification
      t.string :social_name
      t.string :sex
      t.string :race
      t.string :marital_status
      t.string :education_level

      # Birth
      t.string :birth_city
      t.string :birth_state
      t.string :birth_country
      t.string :nationality

      # Documents (encrypted numbers)
      t.text :rg_number
      t.string :rg_issuer
      t.string :rg_state
      t.date :rg_issued_on
      t.text :ctps_number
      t.string :ctps_series
      t.string :ctps_state
      t.text :pis_nis
      t.text :voter_id
      t.text :cnh_number
      t.string :cnh_category
      t.date :cnh_expires_on
      t.text :class_registration
      t.string :class_registration_issuer
      t.text :foreign_registration

      # Address, in Brazil or abroad
      t.boolean :lives_abroad, null: false, default: false
      t.string :postal_code
      t.string :street
      t.string :street_number
      t.string :complement
      t.string :district
      t.string :city
      t.string :ibge_city_code
      t.string :state
      t.string :foreign_country
      t.text :foreign_address

      # Foreign worker
      t.date :arrived_on
      t.string :immigration_condition
      t.boolean :married_to_brazilian
      t.boolean :brazilian_children

      # Disability (encrypted JSON: types, rehabilitated, notes)
      t.text :disability

      # Personal contact
      t.string :personal_phone
      t.string :personal_email

      t.timestamps
    end
  end
end

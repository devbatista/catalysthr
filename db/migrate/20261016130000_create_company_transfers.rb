# Transfers of a company between partners or to and from the direct modality, with the
# company's authorization and who performed it (RN-01-050, D-123, D-599). The
# authorization document, when there is one, is an Active Storage attachment.
class CreateCompanyTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :company_transfers do |t|
      t.references :company, null: false, foreign_key: true
      t.references :from_partner, foreign_key: { to_table: :partners }
      t.references :to_partner, foreign_key: { to_table: :partners }
      t.references :performed_by, null: false, foreign_key: { to_table: :users }
      t.text :authorized_by_text, null: false
      t.datetime :performed_at, null: false
      t.timestamps
    end
  end
end

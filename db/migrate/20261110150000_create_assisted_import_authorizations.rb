# Block 18d-2 of spec 18 (D-665, D-666): the HR administrator's authorization for the support
# to import on the company's behalf (RN-18-061, P-18-18), with the date, 30 days of validity
# and the revocation.
class CreateAssistedImportAuthorizations < ActiveRecord::Migration[8.1]
  def change
    create_table :assisted_import_authorizations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :authorized_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :authorized_at, null: false
      t.datetime :valid_until, null: false
      t.datetime :revoked_at
      t.references :revoked_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end

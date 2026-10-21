# The payments of each invoice in Mercado Pago (spec 19, section 7, RN-19-042, RN-19-046,
# D-622): one row per PIX generated, with the order created in the Orders API, its QR code
# and its due time. The invoice records when it was paid.
class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :invoice, type: :uuid, null: false, foreign_key: true
      t.string :payment_method, null: false
      t.string :status, null: false
      t.bigint :amount_cents, null: false
      t.string :idempotency_key, null: false
      t.string :provider_order_id
      t.string :provider_payment_id
      t.string :raw_status
      t.text :qr_code
      t.text :qr_code_base64
      t.string :ticket_url
      t.datetime :expires_at
      t.datetime :paid_at
      t.timestamps
    end
    add_index :payments, :idempotency_key, unique: true
    add_index :payments, :provider_order_id, unique: true
    add_index :payments, :status

    add_column :invoices, :paid_at, :datetime
  end
end

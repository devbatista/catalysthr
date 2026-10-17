# The company's establishments: headquarters, branches, sites (RN-04-010 to RN-04-014,
# D-201). The position is the base of the time clock's geofence (RN-04-012, D-216).
class CreateUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :units do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :registration_type
      t.string :registration_number
      t.string :postal_code
      t.string :street
      t.string :street_number
      t.string :complement
      t.string :district
      t.string :city
      t.string :ibge_city_code
      t.string :state
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.string :time_zone, null: false, default: "America/Sao_Paulo"
      t.boolean :headquarters, null: false, default: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :units, :company_id, unique: true, where: "headquarters", name: "index_units_on_company_headquarters"
  end
end

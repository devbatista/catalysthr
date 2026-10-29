# Holidays for deadlines in business days (spec 06, RN-06-026, RN-06-029) and, later, the
# time tracking (spec 11, RN-11-020). Two tables (D-638): `holidays`, kept by the
# CatalystHR team for every company (national, state and city), and `unit_holidays`, the
# company's own per unit (holidays, optional days and a national holiday turned off).
class CreateHolidays < ActiveRecord::Migration[8.1]
  def change
    create_table :holidays, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :level, null: false
      t.string :state
      t.string :ibge_city_code
      t.string :city_name
      t.date :date, null: false
      t.string :name, null: false
      # National holidays from BrasilAPI wait for the team's review (P-11-06, D-638).
      t.string :status, null: false, default: "published"
      t.string :source, null: false, default: "manual"
      # A national holiday the HR may turn off in a unit, such as Good Friday (D-638).
      t.boolean :unit_opt_out, null: false, default: false
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :holidays, %i[level state ibge_city_code date], unique: true, nulls_not_distinct: true,
      name: "index_holidays_on_place_and_date"
    add_index :holidays, :date
    add_check_constraint :holidays, <<~SQL.squish, name: "holidays_place"
      (level = 'national' AND state IS NULL AND ibge_city_code IS NULL) OR
      (level = 'state' AND state IS NOT NULL AND ibge_city_code IS NULL) OR
      (level = 'city' AND state IS NOT NULL AND ibge_city_code IS NOT NULL)
    SQL

    create_table :unit_holidays, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.references :unit, type: :uuid, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.date :date, null: false
      t.string :name
      # Only for an opt-out: the national holiday turned off in the unit.
      t.references :holiday, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :unit_holidays, %i[unit_id date], unique: true
    add_index :unit_holidays, %i[company_id date]
  end
end

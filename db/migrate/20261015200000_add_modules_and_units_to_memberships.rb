# Released modules and units of the HR analyst and the consultant (spec 03, section 6,
# P-03-37). Empty units means no unit; the units themselves come with spec 04.
class AddModulesAndUnitsToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :enabled_modules, :string, array: true, null: false, default: []
    add_column :memberships, :unit_ids, :bigint, array: true, null: false, default: []
  end
end

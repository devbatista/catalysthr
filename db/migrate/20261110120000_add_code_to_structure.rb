# Block 18a of spec 18 (D-662): the units, departments and positions get an optional code,
# unique in the company. It is the key of the structure's import and what the other imports
# point to (P-18-08). Indexes built concurrently, so the tables are never locked.
class AddCodeToStructure < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  TABLES = %i[units departments positions].freeze

  def change
    TABLES.each do |table|
      add_column table, :code, :string
      add_index table, %i[company_id code], unique: true, where: "code IS NOT NULL", algorithm: :concurrently
    end
  end
end

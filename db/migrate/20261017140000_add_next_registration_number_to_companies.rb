# The next registration number the company suggests for a new employment (RN-04-002,
# RN-04-052, D-211). The HR may type another one.
class AddNextRegistrationNumberToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :next_registration_number, :integer, null: false, default: 1
  end
end

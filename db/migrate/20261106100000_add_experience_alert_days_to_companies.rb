# The notice's lead time before the end of each experience period (RN-07-101, P-07-15, D-653).
class AddExperienceAlertDaysToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :experience_alert_days, :integer, default: 10, null: false
  end
end

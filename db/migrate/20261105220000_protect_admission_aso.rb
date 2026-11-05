# Block 07d-1 of spec 07 (D-651): fit or unfit is health data (D-086), so aso_status becomes
# encrypted. Without a stored value it reads as "missing". The exam's date is kept to warn
# about an exam after the start. No admission has a result yet: the flag is off and the
# column held only the default.
class ProtectAdmissionAso < ActiveRecord::Migration[8.1]
  def up
    add_column :admissions, :aso_exam_on, :date
    change_column_default :admissions, :aso_status, from: "missing", to: nil
    safety_assured do
      change_column_null :admissions, :aso_status, true
      execute "UPDATE admissions SET aso_status = NULL"
    end
  end

  def down
    change_column_null :admissions, :aso_status, false, "missing"
    change_column_default :admissions, :aso_status, from: nil, to: "missing"
    remove_column :admissions, :aso_exam_on
  end
end

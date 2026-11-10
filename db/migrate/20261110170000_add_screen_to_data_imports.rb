# Block 18f-2 of spec 18 (D-668, D-669): a mass update from the screen (RN-18-030) has no file;
# the filter and the change it applies stay here, encrypted, since the change may carry a
# salary (D-086), and leave with the lines' data after 90 days (RN-18-010).
class AddScreenToDataImports < ActiveRecord::Migration[8.1]
  def change
    add_column :data_imports, :screen, :text
  end
end

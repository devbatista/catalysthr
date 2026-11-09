# Block 18d-1 of spec 18 (D-665): undoing an import (RN-18-050 to RN-18-052). Each recorded
# row keeps what it created and the values it replaced, encrypted, because the sensitive
# fields stay out of PaperTrail (D-086); they leave with the row's data after 90 days
# (RN-18-010). The import keeps what blocks undoing it, also encrypted: it names people.
class AddUndoToDataImports < ActiveRecord::Migration[8.1]
  def change
    add_column :data_import_rows, :undo_data, :text
    add_column :data_imports, :undo_blockers, :text
  end
end

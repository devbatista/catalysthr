# The legal texts moved to legal_documents (D-577). The model has ignored these
# columns since the previous deploy, so no running version reads them.
class RemoveLegalTextsFromBrands < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :brands, :terms_text, :text
      remove_column :brands, :privacy_policy_text, :text
    end
  end
end

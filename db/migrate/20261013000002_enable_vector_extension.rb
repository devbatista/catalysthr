# pgvector for the assistant embeddings (D-102, spec 14).
class EnableVectorExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"
  end
end

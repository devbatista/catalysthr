# Block 15e of spec 15 (D-656): the board of notices (RN-15-070 to RN-15-074, RN-15-091). The
# audience is the filter as chosen, read when someone opens the board (D-656). A read is the
# membership's first opening; the reads leave with their notice.
class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :author, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body, null: false
      t.jsonb :audience, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.datetime :publish_at
      t.datetime :expires_at, null: false
      t.boolean :pinned, null: false, default: false
      t.datetime :published_at
      t.datetime :withdrawn_at
      t.references :withdrawn_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
      t.index %i[company_id status expires_at]
      t.index %i[status publish_at]
    end

    create_table :announcement_reads, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :announcement, type: :uuid, null: false, foreign_key: true, index: false
      t.references :membership, type: :uuid, null: false, foreign_key: true
      t.datetime :read_at, null: false
      t.index %i[announcement_id membership_id], unique: true
    end
  end
end

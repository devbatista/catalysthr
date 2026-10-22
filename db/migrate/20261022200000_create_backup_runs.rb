# The daily pg_dumps and the restore drills (spec 20, section 5, RN-20-041, RN-20-046,
# D-627): when each ran, how it ended, its size, where it went and the drill's checks.
class CreateBackupRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_runs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :kind, null: false
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :duration_seconds
      t.bigint :size_bytes
      t.string :s3_key
      t.jsonb :checks, null: false, default: {}
      t.text :error_message
      t.timestamps
    end
    add_index :backup_runs, %i[kind started_at]
  end
end

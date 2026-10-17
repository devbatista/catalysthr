# An occupation of the official CBO table, global and without a tenant (RN-04-031,
# P-04-13). Loaded from db/data/cbo2002_ocupacao.csv (db/data/README.md).
class CboOccupation < ApplicationRecord
  FILE = Rails.root.join("db/data/cbo2002_ocupacao.csv")
  LINE_FORMAT = /\A(\d{6});(.+)\z/

  scope :active, -> { where(active: true) }

  # The table's rows. The official file has no quotes nor extra separators; a line out of
  # the "code;title" format stops the load instead of loading it wrong.
  def self.rows_from(path = FILE)
    File.readlines(path, chomp: true, encoding: "UTF-8").drop(1).reject(&:blank?).map do |line|
      match = line.match(LINE_FORMAT) or raise ArgumentError, "Linha fora do formato da CBO: #{line.inspect}"
      { code: match[1], title: match[2].strip }
    end
  end

  # Adds the new codes, updates the titles and inactivates the ones that left the table,
  # never deleting them (db/data/README.md). Idempotent.
  def self.import!(path = FILE)
    rows = rows_from(path)
    transaction do
      upsert_all(rows.map { |row| row.merge(active: true) }, unique_by: :code)
      where.not(code: rows.pluck(:code)).update_all(active: false, updated_at: Time.current)
    end
    rows.size
  end

  def self.search(query)
    term = query.to_s.strip
    return none if term.length < 2

    scope = active.order(:code).limit(20)
    term.match?(/\A\d+\z/) ? scope.where("code LIKE ?", "#{term}%") : scope.where("title ILIKE ?", "%#{sanitize_sql_like(term)}%")
  end

  def label
    "#{code} · #{title}"
  end
end

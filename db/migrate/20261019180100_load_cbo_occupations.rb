# First load of the official CBO occupations (db/data/README.md), after the baseline with
# UUID keys (D-614). Later updates go through bin/rails cbo:import. Idempotent.
class LoadCboOccupations < ActiveRecord::Migration[8.1]
  class MigrationOccupation < ActiveRecord::Base
    self.table_name = "cbo_occupations"
  end

  def up
    lines = File.readlines(Rails.root.join("db/data/cbo2002_ocupacao.csv"), chomp: true, encoding: "UTF-8").drop(1).reject(&:blank?)
    rows = lines.map do |line|
      match = line.match(/\A(\d{6});(.+)\z/) or raise ArgumentError, "Linha fora do formato da CBO: #{line.inspect}"
      { code: match[1], title: match[2].strip, active: true }
    end
    MigrationOccupation.upsert_all(rows, unique_by: :code, record_timestamps: true)
  end

  def down
  end
end

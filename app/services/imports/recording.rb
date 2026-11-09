module Imports
  # Records a confirmed import (RN-18-008, P-18-06): only the valid lines, in the kind's order,
  # each in its own transaction, so a line that fails does not undo the others and shows in
  # the result. Every change goes to PaperTrail with who confirmed and the origin
  # "import:<id>" in the request id (RN-18-009). What each line changed is kept to undo it
  # (D-665). Idempotent: a line already recorded is not recorded again.
  module Recording
    module_function

    def call(import)
      return unless import.importing?

      kind = import.kind_class.new(import)
      rows = import.rows.status_valid.to_a
      rows = import.kind_class.order(rows) if import.kind_class.respond_to?(:order)
      undoable = true
      PaperTrail.request(whodunnit: import.created_by_id, controller_info: { request_id: origin(import) }) do
        rows.each_with_index do |row, sequence|
          entries = apply_row(kind, row, sequence)
          undoable = false if entries&.any? { |entry| entry["op"] == "destroy" }
        end
      end
      finish(import, undoable)
    end

    def origin(import)
      "import:#{import.id}"
    end

    # The line's changes go to its tracker, kept encrypted on the row to undo it (D-665).
    def apply_row(kind, row, sequence)
      ActiveRecord::Base.transaction(requires_new: true) do
        record = action = nil
        entries = Tracker.track { record, action = kind.apply(row.sheet, row.payload) }
        row.update!(status: "imported", action: action, record_type: record.class.name, record_id: record.id,
          undo_data: { "sequence" => sequence, "entries" => entries })
        entries
      end
    rescue ActiveRecord::ActiveRecordError, Imports::ApplyError => error
      message = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      row.update!(status: "failed", issues: [ { "column" => nil, "value" => nil, "message" => message.presence || error.class.name } ])
      nil
    end

    # undoable: every line kept what it did, so the import can be undone (D-665).
    def finish(import, undoable)
      counts = import.rows.unscope(:order).group(:status).count
      actions = import.rows.unscope(:order).status_imported.group(:action).count
      failed = counts.fetch("failed", 0)
      # Lines left out because of their errors also make it "with errors" (CA-18-002).
      with_errors = failed.positive? || import.error_count.positive?
      import.update!(status: with_errors ? "completed_with_errors" : "completed", failed_count: failed,
        created_count: actions.fetch("create", 0), updated_count: actions.fetch("update", 0), finished_at: Time.current,
        options: import.options.merge("undoable" => undoable && counts.fetch("imported", 0).positive?))
    end
  end
end

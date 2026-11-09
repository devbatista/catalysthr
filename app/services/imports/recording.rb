module Imports
  # Records a confirmed import (RN-18-008, P-18-06): only the valid lines, in the kind's order,
  # each in its own transaction, so a line that fails does not undo the others and shows in
  # the result. Every change goes to PaperTrail with who confirmed and the origin
  # "import:<id>" in the request id (RN-18-009), the key block 18d undoes by. Idempotent: a
  # line already recorded is not recorded again.
  module Recording
    module_function

    def call(import)
      return unless import.importing?

      kind = import.kind_class.new(import)
      rows = import.rows.status_valid.to_a
      rows = import.kind_class.order(rows) if import.kind_class.respond_to?(:order)
      PaperTrail.request(whodunnit: import.created_by_id, controller_info: { request_id: origin(import) }) do
        rows.each { |row| apply_row(kind, row) }
      end
      finish(import)
    end

    def origin(import)
      "import:#{import.id}"
    end

    def apply_row(kind, row)
      ActiveRecord::Base.transaction(requires_new: true) do
        record, action = kind.apply(row.sheet, row.payload)
        row.update!(status: "imported", action: action, record_type: record.class.name, record_id: record.id)
      end
    rescue ActiveRecord::ActiveRecordError, Imports::Structure::ApplyError => error
      message = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      row.update!(status: "failed", issues: [ { "column" => nil, "value" => nil, "message" => message.presence || error.class.name } ])
    end

    def finish(import)
      counts = import.rows.unscope(:order).group(:status).count
      actions = import.rows.unscope(:order).status_imported.group(:action).count
      failed = counts.fetch("failed", 0)
      # Lines left out because of their errors also make it "with errors" (CA-18-002).
      with_errors = failed.positive? || import.error_count.positive?
      import.update!(status: with_errors ? "completed_with_errors" : "completed", failed_count: failed,
        created_count: actions.fetch("create", 0), updated_count: actions.fetch("update", 0), finished_at: Time.current)
    end
  end
end

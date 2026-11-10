module Imports
  # Reads and validates an import in the background (RN-18-001, steps 3 and 4): the lines go
  # to the preview with their errors, and nothing of the company changes (D-462). Idempotent:
  # running again rebuilds the preview.
  module Validation
    module_function

    def call(import)
      return unless import.uploaded? || import.validating?

      import.update!(status: "validating")
      lines = read(import)
      record(import, import.kind_class.new(import).validate(lines))
    rescue Reader::Error => error
      import.rows.delete_all
      import.update!(status: "failed", failure_reason: I18n.t("imports.reader.#{error.key}", **error.details), validated_at: Time.current)
    end

    # The file's lines or, for a mass update from the screen, the filter's (RN-18-030, D-669).
    def read(import)
      if import.screen.present?
        ability = Ability.new(import.created_by, area: :panel, company: import.company)
        return import.kind_class.screen_lines(import, ability)
      end

      import.file.open { |io| Reader.new(import.kind_class, io, import.original_filename).read }
    end

    # The preview's rows and counts (RN-18-006). Each row goes through the model, so its data
    # are encrypted.
    def record(import, results)
      DataImport.transaction do
        import.rows.delete_all
        results.each_with_index do |result, position|
          import.rows.create!(company_id: import.company_id, sheet: result.sheet.to_s, line_number: result.line, position: position,
            status: result.status, action: result.action, payload: result.values, issues: result.issues, diff: result.diff)
        end
        counts = results.group_by(&:status).transform_values(&:size)
        actions = results.select { |result| result.status == "valid" }.group_by(&:action).transform_values(&:size)
        import.update!(status: "preview", row_count: results.size, valid_count: counts.fetch("valid", 0),
          error_count: counts.fetch("invalid", 0), unchanged_count: counts.fetch("unchanged", 0),
          created_count: actions.fetch("create", 0), updated_count: actions.fetch("update", 0), validated_at: Time.current)
      end
    end
  end
end

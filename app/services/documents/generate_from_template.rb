module Documents
  # Generating a contract or term (RN-07-042, CA-07-004, D-650): says what's blank, so the HR
  # fills it or confirms, and stops on a value the PDF's font doesn't have, instead of a
  # silent "?". Generating again replaces the PDF not yet signed. The PDF itself comes from
  # Documents::GenerateFromTemplateJob.
  class GenerateFromTemplate
    def initialize(employment, template)
      @employment = employment
      @template = template
    end

    def missing
      values.select { |_name, value| value.blank? }.keys
    end

    def unsupported
      values.values.flat_map { |value| ContractPdf.unsupported(value) }.uniq
    end

    # Nil when the signed one is already in the folder.
    def request(by:)
      generated = @employment.with_lock do
        record = GeneratedDocument.find_or_initialize_by(employment: @employment, document_template: @template)
        next if record.signed?

        record.file.purge if record.file.attached? && !Simulation.active?
        record.update!(status: "generating", generated_by: by, generated_at: nil, missing_variables: missing)
        record
      end
      GenerateFromTemplateJob.perform_later(generated) if generated
      generated
    end

    private

    def values
      @values ||= TemplateVariables.new(@employment).values(@template.variables)
    end
  end
end

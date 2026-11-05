module Documents
  # The PDF of a contract or term (spec 07, section 8), with the data of now. Runs again
  # without repeating: only what is still generating. The PDF goes under the company's prefix
  # with its encryption (P-08-07), and never to the logs: a failure says only the record.
  class GenerateFromTemplateJob < ApplicationJob
    queue_as :default

    retry_on ActiveStorage::Error, wait: :polynomially_longer, attempts: 5

    def perform(generated)
      return unless generated.generating?

      template = generated.document_template
      values = TemplateVariables.new(generated.employment).values(template.variables)
      pdf = ContractPdf.new(title: template.name, body: template.body, values: values).render
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(pdf), filename: "#{template.name.parameterize}.pdf",
        content_type: Upload::PDF, identify: false, key: Upload.storage_key(generated.company))
      generated.file.attach(blob)
      generated.update!(status: "ready", generated_at: Time.current)
    rescue Prawn::Errors::IncompatibleStringEncoding
      generated.update!(status: "failed")
    end
  end
end

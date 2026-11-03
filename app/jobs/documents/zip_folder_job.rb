require "open3"

module Documents
  # Makes a person's folder in ZIP for who asked it (RN-08-082, P-08-21, D-644): the version
  # in force of each document they may read when the job runs, a folder per category, and
  # an index with the type, the date, the status and the hash. 7-Zip, already in the
  # container (D-514), writes it without a password (D-642); it goes to the storage under
  # the company's prefix and is served for 24 hours. Runs once per export.
  class ZipFolderJob < ApplicationJob
    queue_as :reports

    class Failed < StandardError; end

    def perform(export)
      return unless export.queued?

      ability = Ability.new(export.requested_by, area: :panel, company: export.company)
      documents = Document.kept.accessible_by(ability, :read).where(worker_profile: export.worker_profile)
        .where.not(current_version_id: nil).includes(:document_type, :dependent, current_version: { pdf_attachment: :blob }).to_a
        .select { |document| document.current_version.readable? }
      Dir.mktmpdir("folder") do |dir|
        zip_path = File.join(dir, "pasta.zip")
        build(dir, documents, zip_path)
        blob = File.open(zip_path, "rb") do |file|
          ActiveStorage::Blob.create_and_upload!(io: file, filename: "documentos-#{export.created_at.to_date.iso8601}.zip",
            content_type: "application/zip", identify: false, key: "companies/#{export.company_id}/exports/#{SecureRandom.uuid}")
        end
        export.zip.attach(blob)
      end
      export.update!(status: "ready", documents_count: documents.size, expires_at: DocumentFolderExport::LIFETIME.from_now)
    rescue Failed => error
      export.update!(status: "failed")
      Sentry.capture_exception(error)
    end

    private

    def build(dir, documents, zip_path)
      root = File.join(dir, "documentos")
      FileUtils.mkdir_p(root)
      names = Hash.new(0)
      index = documents.sort_by { |document| [ DocumentCategory::ALL.index(document.category), document.document_type.name ] }.map do |document|
        version = document.current_version
        folder = File.join(root, safe(I18n.t("documents.categories.#{document.category}")))
        FileUtils.mkdir_p(folder)
        base = safe([ document.document_type.name, document.dependent&.name ].compact.join(" - "))
        names[[ folder, base ]] += 1
        name = names[[ folder, base ]] > 1 ? "#{base} (#{names[[ folder, base ]]}).pdf" : "#{base}.pdf"
        File.binwrite(File.join(folder, name), version.pdf.download)
        index_line(document, version, File.join(File.basename(folder), name))
      end
      File.write(File.join(root, "indice.txt"), ([ I18n.t("documents.export.index_header") ] + index).join("\n") + "\n")

      _out, err, status = Open3.capture3("7z", "a", "-tzip", "-bd", zip_path, "documentos", chdir: dir)
      raise Failed, "7z exited with #{status.exitstatus}: #{err.strip.first(300)}" unless status.success?
    end

    def index_line(document, version, name)
      [ name, document.document_type.name, I18n.l(version.reviewed_at || version.uploaded_at, format: "%d/%m/%Y"),
        I18n.t("documents.statuses.#{document.status}"), document.expires_on ? I18n.l(document.expires_on) : "-", version.sha256 ].join(" | ")
    end

    # A name without the characters a file system refuses.
    def safe(name)
      name.to_s.gsub(%r{[/\\:*?"<>|]}, "-").squish.first(120)
    end
  end
end

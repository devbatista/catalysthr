require "securerandom"

module Exports
  # Makes the company's full export in the background (RN-18-073, P-18-22, D-667), in the
  # `imports` queue, with low concurrency so it does not compete with time tracking and payroll
  # (spec 20, P-18-26). The content goes to a temporary folder, the 7-Zip protects it with the
  # password the system generates (RN-18-075), in volumes of up to 5 GB, and the parts go to the
  # storage under the company's prefix. When ready, who asked gets exports.company_ready; the
  # link lasts 7 days. Running again starts the export over, without a second notice.
  class CompanyJob < ApplicationJob
    queue_as :imports

    PASSWORD_LENGTH = 24

    # A failure tries again with a growing interval; after the last, the export is failed, with
    # nothing left in the storage, and the company may ask again (RN-18-074).
    retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
      job.fail!(job.arguments.first, error)
    end

    def perform(export)
      ActsAsTenant.with_tenant(export.company) do
        return unless export.status.in?(%w[queued generating])

        export.parts.purge if export.parts.attached?
        export.update!(status: "generating", started_at: Time.current, password: export.password.presence || generate_password)
        Dir.mktmpdir("company-export") do |dir|
          root = File.join(dir, "conteudo")
          archive = CompanyArchive.new(export.company, root).write!
          zip_path = File.join(dir, file_name(export))
          paths = SevenZip.encrypt!(dir: root, entries: archive.entries, zip_path: zip_path, password: export.password,
            volume_size: CompanyExport::PART_SIZE)
          size = paths.sum { |path| File.size(path) }
          paths.each { |path| attach(export, path) }
          export.update!(status: "ready", ready_at: Time.current, expires_at: CompanyExport::LIFETIME.from_now,
            records_count: archive.records_count, files_count: archive.files_count, size_bytes: size)
        end
        notify(export)
      end
    end

    def fail!(export, error)
      ActsAsTenant.with_tenant(export.company) do
        export.parts.purge if export.parts.attached?
        export.update!(status: "failed", failed_at: Time.current, password: nil)
      end
      Sentry.capture_exception(error)
    end

    private

    # Letters and digits without the ones read wrong (0, O, 1, l, I), so it can be typed.
    def generate_password
      alphabet = [ *"A".."Z", *"a".."z", *"2".."9" ] - %w[O I l]
      Array.new(PASSWORD_LENGTH) { alphabet[SecureRandom.random_number(alphabet.size)] }.join
    end

    def file_name(export)
      "catalysthr-export-#{export.company.name.parameterize.presence || "empresa"}-#{export.created_at.in_time_zone.strftime("%Y%m%d")}.zip"
    end

    def attach(export, path)
      blob = File.open(path, "rb") do |file|
        ActiveStorage::Blob.create_and_upload!(io: file, filename: File.basename(path), content_type: "application/zip",
          identify: false, key: "companies/#{export.company_id}/exports/#{SecureRandom.uuid}")
      end
      export.parts.attach(blob)
    end

    # Once per export: the notice's key is the export (RN-15-085).
    def notify(export)
      membership = Membership.active.find_by(user: export.requested_by, organization: export.company)
      return unless membership

      Notifications.notify!("exports.company_ready", user: export.requested_by, membership: membership, subject: export,
        path: "/data-exports/#{export.id}", date: I18n.l(export.expires_at.in_time_zone.to_date))
    end
  end
end

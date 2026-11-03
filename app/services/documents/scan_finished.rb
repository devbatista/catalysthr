module Documents
  # When the scan of a file ends, the version it belongs to moves on (RN-08-020, D-642). The
  # scan has no company, so the company comes from the file's key, which the upload builds
  # with it (P-08-07); the version is then read inside that company only.
  module ScanFinished
    KEY = %r{\Acompanies/(?<company_id>[0-9a-f-]{36})/documents/}

    module_function

    def call(scan)
      company_id = scan.blob.key[KEY, :company_id]
      company = company_id && Company.find_by(id: company_id)
      return unless company

      ActsAsTenant.with_tenant(company) do
        ids = ActiveStorage::Attachment.where(blob_id: scan.blob_id, record_type: "DocumentVersion", name: "files").pluck(:record_id)
        DocumentVersion.where(id: ids).find_each { |version| ConsolidatePdfJob.perform_later(version) }
      end
    end
  end
end

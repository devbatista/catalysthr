module Announcements
  # When the scan of a notice's attachment ends, the notice waiting for it goes up, or back
  # to the drafts with a virus (D-656). The scan has no company, so the company comes from the
  # file's key, which the form builds with it; the notice is then read inside that company.
  module ScanFinished
    KEY = %r{\Acompanies/(?<company_id>[0-9a-f-]{36})/announcements/}

    module_function

    def call(scan)
      company_id = scan.blob.key[KEY, :company_id]
      company = company_id && Company.find_by(id: company_id)
      return unless company

      ActsAsTenant.with_tenant(company) do
        ids = ActiveStorage::Attachment.where(blob_id: scan.blob_id, record_type: "Announcement", name: "attachment").pluck(:record_id)
        Announcement.scheduled.where(id: ids).find_each { |announcement| Publish.call(announcement) }
      end
    end
  end
end

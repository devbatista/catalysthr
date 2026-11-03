module Documents
  # Every day, deletes from the storage the files of the documents deleted more than 30
  # days ago, ending their recovery (RN-08-083, P-08-22, CA-08-010), and the folders' ZIPs
  # past their 24 hours (P-08-21). The rows stay, for the trail. A file another document
  # still uses, such as a publication's (D-643), stays.
  class PurgeDeletedJob < ApplicationJob
    queue_as :default

    def perform
      company_ids = (CrossCompany.scope(Document, Company.all).where(purged_at: nil, deleted_at: ...Removal::RECOVERABLE_FOR.ago).pluck(:company_id) +
        CrossCompany.scope(DocumentFolderExport, Company.all).ready.where(expires_at: ...Time.current).pluck(:company_id)).uniq
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) do
          purge_documents
          expire_exports
        end
      end
    end

    private

    def purge_documents
      Document.where(purged_at: nil, deleted_at: ...Removal::RECOVERABLE_FOR.ago).includes(:versions).find_each do |document|
        document.versions.each do |version|
          (version.files.attachments + [ version.pdf.attachment ].compact).each do |attachment|
            blob = attachment.blob
            attachment.delete
            blob.purge_later if blob.attachments.reload.none?
          end
        end
        document.update!(purged_at: Time.current)
      end
    end

    def expire_exports
      DocumentFolderExport.ready.where(expires_at: ...Time.current).find_each do |export|
        export.zip.purge_later
        export.update!(status: "expired")
      end
    end
  end
end

module Documents
  # What follows a document's versions (D-642, D-643): the process item it answers
  # (RN-06-010) and the requests waiting for it (RN-08-041).
  module Followers
    module_function

    def sync(document, by:)
      Processes::DocumentItem.sync(document, by: by)
      status = DocumentRequestTarget.status_for(document.latest_version)
      document.request_targets.where.not(status: status).find_each { |target| target.update!(status: status) }
    end
  end
end

# The panel only opens after the terms and the policy in force are accepted
# (RN-02-014, RN-02-017).
module LegalDocumentsHelper
  def publish_platform_legal_documents
    author = create(:user, platform_role: "superadmin")
    LegalDocument::KINDS.map { |kind| create(:legal_document, kind: kind, published_by: author) }
  end

  def accept_legal_documents(user, brand)
    LegalAcceptance.new(user, brand).accept!(ip: "127.0.0.1", user_agent: "RSpec")
  end
end

RSpec.configure do |config|
  config.include LegalDocumentsHelper
end

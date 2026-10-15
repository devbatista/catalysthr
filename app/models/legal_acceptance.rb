# The step of the terms of use and the privacy policy: in the first access (RN-02-014,
# item 2) and again whenever the brand publishes a new version (RN-02-017). The texts
# are the subdomain brand's or, without them, the CatalystHR's (D-578).
class LegalAcceptance
  def initialize(user, brand)
    @user = user
    @brand = brand
  end

  def documents
    @documents ||= LegalDocument::KINDS.index_with { |kind| LegalDocument.current_for(@brand, kind) }
  end

  # Without a published text there is nothing to accept, and the first access waits (D-578).
  def published?
    documents.values.all?
  end

  def pending
    documents.values.compact.reject { |document| @user.consents.granted.exists?(legal_document: document) }
  end

  def pending?
    !published? || pending.any?
  end

  def accept!(ip:, user_agent:)
    pending.each do |document|
      Consent.accept!(user: @user, legal_document: document, scope: @brand, ip: ip, user_agent: user_agent)
    end
  end
end

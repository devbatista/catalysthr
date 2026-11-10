module Documents
  # What follows a version that reached the review, with or without the AI (RN-08-020): a
  # published document is approved by who published it, and its acknowledgments are asked
  # (D-643); any other one updates its process items and requests.
  module ReadyForReview
    module_function

    def call(version)
      document = version.document
      if version.awaiting_review? && (publication = document.publication)
        Review.new(version, by: publication.published_by).approve
        document.acknowledgments.awaiting.find_each do |acknowledgment|
          Notices.employee("documents.acknowledgment_pending", document, subject: acknowledgment, title: publication.title,
            due: I18n.l(acknowledgment.due_on))
        end
      else
        Followers.sync(document, by: version.uploaded_by)
      end
    end

    # Whether a clean version goes to the AI first (RN-14-020, CA-14-003): a platform type with
    # a profile, not a published one, and the company's AI available or only waiting for the
    # circuit breaker. Otherwise it goes straight to the review.
    def ai_reading?(version)
      document = version.document
      return false if document.publication || document.document_type.ai_extraction_profile.blank?

      Ai::Availability.check(version.company, "document_extraction").in?(%i[available breaker])
    end
  end
end

module Documents
  # The HR's request for a document (RN-08-040, RN-08-041, D-278, D-643): the type, the
  # people, the date and a message. Each person gets a pending document in the folder and a
  # target that follows it. The person's notice comes with the portal (spec 16).
  class RequestForm
    include ActiveModel::Model

    attr_accessor :document_type, :audience_filter, :due_on, :message, :by, :ability
    attr_reader :request

    validates :document_type, presence: true
    validates :message, length: { maximum: 2000 }
    validate :date_ahead
    validate :someone

    def audience
      @audience ||= Audience.new(audience_filter, ability: ability, document_type: document_type)
    end

    def people
      @people ||= audience.profiles
    end

    def save
      return false unless valid?

      ActiveRecord::Base.transaction do
        @request = DocumentRequest.create!(document_type: document_type, requested_by: by, due_on: due_on, message: message,
          audience_filter: audience.filter)
        people.each do |profile|
          document = Document.create!(worker_profile: profile, document_type: document_type, source: "hr", source_ref: @request)
          @request.targets.create!(worker_profile: profile, document: document)
        end
      end
      true
    end

    private

    def date_ahead
      errors.add(:due_on, :past) if due_on.present? && due_on < Time.zone.today
    end

    def someone
      return if document_type.nil?

      errors.add(:base, audience.empty? ? :audience_blank : :nobody) if people.empty?
    end
  end
end

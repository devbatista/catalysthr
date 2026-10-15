module Users
  # Who administers the profile corrects the e-mail or the mobile phone of a person who
  # lost both, so the person recovers the access alone (RN-02-033, P-02-17). The old
  # e-mail is told about the change (D-582). The change stays in the trail, and an access
  # event records who made it, without the values.
  class CorrectContact
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, email:, mobile_phone:, by:, brand: nil)
      @membership = membership
      @brand = brand
      @email = email
      @mobile_phone = mobile_phone
      @by = by
    end

    def call
      user = @membership.user
      old_email = user.email
      user.update!(email: @email, mobile_phone: @mobile_phone)

      changed = user.saved_changes.keys & %w[email mobile_phone]
      return user if changed.empty?

      AccessEvent.record!(kind: "admin", action: "contact_corrected", user: @by, subject: @membership,
        metadata: { fields: changed })
      AccountMailer.contact_changed(@membership, old_email, @brand).deliver_later if old_email.present? && changed.include?("email")
      user
    end
  end
end

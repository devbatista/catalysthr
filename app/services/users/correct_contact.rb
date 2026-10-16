module Users
  # Corrects the e-mail or the mobile phone of a person who lost both, so the person
  # recovers the access alone (RN-02-033, P-02-17): by who administers the profile,
  # through the membership, or by the CatalystHR support, with the reason (D-582). The old
  # e-mail is told about the change. The change stays in the trail, and an access event
  # records who made it, without the values.
  class CorrectContact
    def self.call(**)
      new(**).call
    end

    # membership and brand say on whose behalf the e-mail goes; without them, CatalystHR.
    def initialize(user:, email:, mobile_phone:, by:, membership: nil, brand: nil, reason: nil)
      @user = user
      @email = email
      @mobile_phone = mobile_phone
      @by = by
      @membership = membership
      @brand = brand
      @reason = reason
    end

    def call
      old_email = @user.email
      @user.update!(email: @email, mobile_phone: @mobile_phone)

      changed = @user.saved_changes.keys & %w[email mobile_phone]
      return @user if changed.empty?

      AccessEvent.record!(kind: "admin", action: "contact_corrected", user: @by, subject: @membership || @user,
        metadata: { fields: changed, reason: @reason }.compact)
      if old_email.present? && changed.include?("email")
        AccountMailer.contact_changed(@user, old_email, @membership, @brand).deliver_later
      end
      @user
    end
  end
end

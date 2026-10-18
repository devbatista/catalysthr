module Users
  # The support releases an address that bounced, after the person fixed the mailbox
  # (RN-15-083, D-609): the mark goes away, and the address leaves SES's account
  # suppression list, which would drop every e-mail to it. Always with the reason, in an
  # access event, without the address.
  class ReleaseEmail
    def self.call(**)
      new(**).call
    end

    def initialize(user:, by:, reason:)
      @user = user
      @by = by
      @reason = reason
    end

    def call
      Brands::EmailIdentity.client.delete_suppressed_destination(email_address: @user.email)
      release
    rescue Aws::SESV2::Errors::NotFoundException
      # Not on the list: only the mark is left.
      release
    end

    private

    def release
      @user.update!(email_status: "valid", email_status_at: Time.current)
      AccessEvent.record!(kind: "admin", action: "email_released", user: @by, subject: @user, metadata: { reason: @reason })
      @user
    end
  end
end

module Panel
  # A passkey in place of the password before sensitive data, for the same 5 minutes
  # (RN-16-073, RN-02-052, D-183). Only the person's own passkeys of this address serve, and
  # it is never offered during an impersonate (RN-02-087).
  class SensitivePasskeyConfirmationsController < BaseController
    # Open while the contract is read only (D-624).
    writes_while_locked :challenge, :create

    include SensitiveAccess
    include PasskeyCeremony

    before_action :forbidden, if: :impersonating?

    def challenge
      authorize! :manage, :own_security
      return refuse_passkey(t(".none")) unless own_passkeys.exists?

      options = relying_party.options_for_authentication(user_verification: "required", allow_credentials: descriptors)
      keep_challenge(:confirmation, options.challenge)
      render json: options
    end

    def create
      authorize! :manage, :own_security
      kept = take_challenge(:confirmation)
      return refuse_passkey(t(".expired")) if kept.nil?

      if verified_passkey(kept["challenge"], own_passkeys)
        confirm_sensitive_access!
        render json: { redirect_to: safe_return_to }
      else
        AccessEvent.record!(kind: "auth", action: "sensitive_confirmation_failed", user: current_user)
        refuse_passkey(t(".refused"))
      end
    end

    private

    def own_passkeys
      current_user.webauthn_credentials.active.at(request.host)
    end

    def descriptors
      own_passkeys.map do |passkey|
        { type: "public-key", id: passkey.external_id, transports: passkey.transports.presence }.compact
      end
    end
  end
end

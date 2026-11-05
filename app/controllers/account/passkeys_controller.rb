module Account
  # The person's own passkeys (RN-16-070, RN-16-076, D-647): registering asks for the
  # password, and for the MFA already on when the profile requires it. Each new one is told
  # to the person, because changing the password does not remove it (P-16-20). They stay out
  # of a support entry, which is not the person's own access.
  class PasskeysController < BaseController
    include PasskeyCeremony

    before_action :forbidden, if: -> { Current.support_access }

    def challenge
      authorize! :manage, :own_security
      return refuse_passkey(t("account.invalid_password")) unless current_password_valid?

      obstacle = registration_obstacle
      return refuse_passkey(obstacle) if obstacle

      options = relying_party.options_for_registration(user: account_entity, exclude: passkeys_here.pluck(:external_id),
        authenticator_selection: { resident_key: "required", require_resident_key: true, user_verification: "required" },
        attestation: "none")
      keep_challenge(:registration, options.challenge, nickname: nickname)
      render json: options
    end

    def create
      authorize! :manage, :own_security
      kept = take_challenge(:registration)
      return refuse_passkey(t(".expired")) if kept.nil?

      credential = parse_credential { relying_party.verify_registration(raw_credential, kept["challenge"], user_verification: true) }
      return refuse_passkey(t(".refused")) if credential.nil?

      passkey = register(credential, kept["nickname"])
      return refuse_passkey(t(".limit", count: WebauthnCredential::MAX_PER_USER)) if passkey.nil?

      flash[:notice] = t(".created")
      render json: { redirect_to: account_root_path(anchor: "passkeys") }
    end

    def destroy
      authorize! :manage, :own_security
      passkey = current_user.webauthn_credentials.active.find(params[:id])
      passkey.remove!
      current_user.record_auth_event("passkey_removed", rp_id: passkey.rp_id)
      redirect_to account_root_path(anchor: "passkeys"), notice: t(".removed")
    end

    private

    def nickname
      params[:nickname].to_s.strip
    end

    def registration_obstacle
      if current_user.mfa_required? && !current_user.mfa_enabled?
        t("account.passkeys.challenge.mfa_first")
      elsif current_user.webauthn_credentials.active.count >= WebauthnCredential::MAX_PER_USER
        t("account.passkeys.create.limit", count: WebauthnCredential::MAX_PER_USER)
      elsif nickname.blank? || nickname.length > WebauthnCredential::NICKNAME_LIMIT
        t("account.passkeys.challenge.nickname", count: WebauthnCredential::NICKNAME_LIMIT)
      end
    end

    # What the device keeps and shows: the e-mail or, without one, the name, never the CPF
    # (D-647). The identifier is random.
    def account_entity
      { id: current_user.ensure_webauthn_handle!, name: current_user.email.presence || current_user.name, display_name: current_user.name }
    end

    def passkeys_here
      current_user.webauthn_credentials.active.at(request.host)
    end

    # The limit again, under the lock, for two ceremonies at the same time.
    def register(credential, passkey_nickname)
      passkey = current_user.with_lock do
        next if current_user.webauthn_credentials.active.count >= WebauthnCredential::MAX_PER_USER

        current_user.webauthn_credentials.create!(rp_id: request.host, external_id: credential.id, public_key: credential.public_key,
          sign_count: credential.sign_count, nickname: passkey_nickname, transports: Array(credential.response.transports),
          aaguid: credential.response.aaguid)
      end
      tell_about(passkey) if passkey
      passkey
    end

    def tell_about(passkey)
      current_user.record_auth_event("passkey_added", rp_id: passkey.rp_id)
      Notifications.notify!("security.passkey_added", user: current_user, brand: Current.brand, area: Current.area.to_s, subject: passkey,
        path: "/security", nickname: passkey.nickname, brand_name: Current.brand&.commercial_name || BrandSender::PLATFORM_NAME)
    end
  end
end

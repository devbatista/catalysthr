module Panel
  # The company's users (spec 03, section 4.2): inviting HR and managers, their roles and
  # modules, invitations, removal, MFA reset and contact correction. A membership of
  # another company is not found (404, RN-01-013); inside the company, a denied action
  # answers 403 (RN-03-006).
  class MembershipsController < BaseController
    before_action :require_current_company
    before_action :load_membership, except: %i[index new create]
    # Pages with an invitation link must not stay in any cache.
    before_action { response.headers["Cache-Control"] = "no-store" }

    def index
      authorize! :read, Membership
      @memberships = Membership.accessible_by(current_ability).where(organization: Current.company)
        .where.not(status: "revoked").includes(:user).order(:status, "users.name").references(:users)
    end

    def show
      authorize! :read, @membership
    end

    def new
      authorize! :invite, Membership
      @form = invite_params_or_defaults
    end

    def create
      authorize! :invite, Membership
      @form = invite_params_or_defaults
      @invitation = Invitations::Create.call(
        organization: Current.company, roles: @form[:roles] & CompanyAbility::INVITABLE_ROLES,
        enabled_modules: @form[:enabled_modules], channels: @form[:channels], invited_by: current_user,
        name: @form[:name], cpf: @form[:cpf], email: @form[:email].presence, mobile_phone: @form[:mobile_phone].presence
      )
      render :invited
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render :new, status: :unprocessable_content
    end

    def edit
      authorize! :update, @membership
    end

    def update
      authorize! :update, @membership
      roles = Array(params.dig(:membership, :roles)) & CompanyAbility::INVITABLE_ROLES
      Memberships::UpdateAccess.call(membership: @membership, roles: roles,
        enabled_modules: params.dig(:membership, :enabled_modules), by: current_user)
      redirect_to membership_path(@membership), notice: t(".updated")
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render :edit, status: :unprocessable_content
    end

    def destroy
      authorize! (@membership.invited? ? :cancel_invitation : :revoke), @membership
      Memberships::Revoke.call(membership: @membership, by: current_user)
      redirect_to memberships_path, notice: t(".revoked")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to membership_path(@membership), alert: error.record.errors.full_messages.to_sentence
    end

    def resend_invitation
      authorize! :resend_invitation, @membership
      @invitation = Invitations::Resend.call(membership: @membership, channels: Array(params[:channels]),
        invited_by: current_user)
      render :invited
    rescue ActiveRecord::RecordInvalid => error
      redirect_to membership_path(@membership), alert: error.record.errors.full_messages.to_sentence
    end

    def reset_mfa
      authorize! :reset_mfa, @membership
      Users::ResetMfa.call(membership: @membership, by: current_user)
      redirect_to membership_path(@membership), notice: t(".reset")
    end

    def contact
      authorize! :correct_contact, @membership
      Users::CorrectContact.call(membership: @membership, email: params[:email].presence,
        mobile_phone: params[:mobile_phone].presence, by: current_user)
      redirect_to membership_path(@membership), notice: t(".corrected")
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render :show, status: :unprocessable_content
    end

    private

    def load_membership
      @membership = Membership.where(organization: Current.company).where.not(status: "revoked").find(params[:id])
    end

    def invite_params_or_defaults
      permitted = params.fetch(:invitation, {}).permit(:name, :cpf, :email, :mobile_phone, roles: [], enabled_modules: [], channels: [])
      { roles: [], enabled_modules: [], channels: %w[email] }.merge(permitted.to_h.symbolize_keys) do |_key, default, given|
        given.is_a?(Array) ? given.compact_blank : given || default
      end
    end
  end
end

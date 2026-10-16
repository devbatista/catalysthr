module Panel
  # The company's users (spec 03, section 4.2): inviting HR and managers, their roles and
  # modules, invitations, removal, MFA reset and contact correction. A membership of
  # another company is not found (404, RN-01-013); inside the company, a denied action
  # answers 403 (RN-03-006).
  #
  # The partner's team and the HR of the partner's client companies reuse these actions
  # and views, with their own organization, roles and permissions (spec 03, section 4.1).
  class MembershipsController < BaseController
    before_action :require_current_company
    before_action :load_membership, except: %i[index new create]
    # Pages with an invitation link must not stay in any cache.
    before_action { response.headers["Cache-Control"] = "no-store" }

    helper_method :membership_organization, :membership_permission, :invitable_roles, :releases_modules?,
      :assignable_companies, :membership_collection_subject

    def index
      authorize! membership_permission(:read), membership_collection_subject
      @memberships = memberships_listing.includes(:user).order(:status, "users.name").references(:users)
    end

    def show
      authorize! membership_permission(:read), @membership
    end

    def new
      authorize! membership_permission(:invite), membership_collection_subject
      @form = invite_params_or_defaults
    end

    def create
      authorize! membership_permission(:invite), membership_collection_subject
      @form = invite_params_or_defaults
      @invitation = Invitations::Create.call(
        organization: membership_organization, roles: @form[:roles] & invitable_roles,
        enabled_modules: releases_modules? ? @form[:enabled_modules] : [], channels: @form[:channels],
        invited_by: current_user, name: @form[:name], cpf: @form[:cpf], email: @form[:email].presence,
        mobile_phone: @form[:mobile_phone].presence, brand: invitation_brand
      )
      if assignable_companies
        Memberships::AssignCompanies.call(membership: @invitation.membership, company_ids: @form[:company_ids], by: current_user)
      end
      render "panel/memberships/invited"
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render "panel/memberships/new", status: :unprocessable_content
    end

    def edit
      authorize! membership_permission(:update), @membership
    end

    def update
      authorize! membership_permission(:update), @membership
      # Roles given elsewhere, such as the employee's, stay as they are.
      roles = (@membership.roles - invitable_roles) + (Array(params.dig(:membership, :roles)) & invitable_roles)
      modules = releases_modules? ? params.dig(:membership, :enabled_modules) : @membership.enabled_modules
      Memberships::UpdateAccess.call(membership: @membership, roles: roles, enabled_modules: modules, by: current_user,
        company_ids: assignable_companies && Array(params.dig(:membership, :company_ids)))
      redirect_to membership_return_url(@membership), notice: t("panel.memberships.update.updated")
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render "panel/memberships/edit", status: :unprocessable_content
    end

    def destroy
      authorize! membership_permission(@membership.invited? ? :cancel_invitation : :revoke), @membership
      Memberships::Revoke.call(membership: @membership, by: current_user)
      redirect_to url_for(action: :index), notice: t("panel.memberships.destroy.revoked")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to url_for(action: :show, id: @membership), alert: error.record.errors.full_messages.to_sentence
    end

    def resend_invitation
      authorize! membership_permission(:resend_invitation), @membership
      @invitation = Invitations::Resend.call(membership: @membership, channels: Array(params[:channels]),
        invited_by: current_user, brand: invitation_brand)
      render "panel/memberships/invited"
    rescue ActiveRecord::RecordInvalid => error
      redirect_to url_for(action: :show, id: @membership), alert: error.record.errors.full_messages.to_sentence
    end

    def reset_mfa
      authorize! membership_permission(:reset_mfa), @membership
      Users::ResetMfa.call(user: @membership.user, membership: @membership, by: current_user, brand: Current.brand)
      redirect_to url_for(action: :show, id: @membership), notice: t("panel.memberships.reset_mfa.reset")
    end

    def contact
      authorize! membership_permission(:correct_contact), @membership
      Users::CorrectContact.call(user: @membership.user, membership: @membership, email: params[:email].presence,
        mobile_phone: params[:mobile_phone].presence, by: current_user, brand: Current.brand)
      redirect_to url_for(action: :show, id: @membership), notice: t("panel.memberships.contact.corrected")
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render "panel/memberships/show", status: :unprocessable_content
    end

    private

    # Where the people are invited to.
    def membership_organization
      Current.company
    end

    # The Ability action that allows each of these actions here. Nil means the action
    # is not offered on this screen.
    def membership_permission(action)
      action
    end

    # What index, new and create authorize: a membership of this organization.
    def membership_collection_subject
      Membership.new(organization: membership_organization)
    end

    def membership_scope
      Membership.where(organization: membership_organization).where.not(status: "revoked")
    end

    def memberships_listing
      membership_scope.accessible_by(current_ability)
    end

    def invitable_roles
      CompanyAbility::INVITABLE_ROLES
    end

    # Whether this screen releases the modules of the HR analyst or the consultant
    # (P-03-06).
    def releases_modules?
      true
    end

    # The brand of the invitation link, when the organization has none of its own, as an
    # accounting firm (D-586).
    def invitation_brand
      nil
    end

    # The companies a consultant can be assigned to, on the partner's team (D-052).
    def assignable_companies
      nil
    end

    # Where to go after changing a person's access.
    def membership_return_url(membership)
      url_for(action: :show, id: membership)
    end

    def load_membership
      @membership = membership_scope.find(params[:id])
    end

    def invite_params_or_defaults
      permitted = params.fetch(:invitation, {})
        .permit(:name, :cpf, :email, :mobile_phone, roles: [], enabled_modules: [], channels: [], company_ids: [])
      defaults = { roles: invitable_roles.one? ? invitable_roles : [], enabled_modules: [], channels: %w[email], company_ids: [] }
      defaults.merge(permitted.to_h.symbolize_keys) do |_key, default, given|
        given.is_a?(Array) ? given.compact_blank : given || default
      end
    end
  end
end

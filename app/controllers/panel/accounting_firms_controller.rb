module Panel
  # The company's accounting firm, managed by the HR administrator (RN-02-070 to
  # RN-02-073, D-588 to D-590): register a new firm and invite its first administrator,
  # or ask an existing one to accept; resend that first invitation; end the link.
  class AccountingFirmsController < BaseController
    before_action :require_current_company
    before_action :load_link
    # Pages with an invitation link must not stay in any cache.
    before_action { response.headers["Cache-Control"] = "no-store" }

    def show
      authorize! :read, link_subject
      @pending_admins = pending_admins
    end

    def new
      authorize! :link, link_subject
      return redirect_to(accounting_firm_path) if @link

      @form = form_params
    end

    def create
      authorize! :link, link_subject
      @form = form_params
      result = AccountingFirms::Link.call(company: Current.company, name: @form[:name], cnpj: @form[:cnpj], by: current_user,
        admin: { name: @form[:admin_name], cpf: @form[:admin_cpf], email: @form[:admin_email].presence,
                 mobile_phone: @form[:admin_mobile_phone].presence, channels: @form[:channels] })
      @link = result.link
      @invitation = result.invitation
      render :linked
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render :new, status: :unprocessable_content
    end

    def destroy
      authorize! :unlink, @link || link_subject
      raise ActiveRecord::RecordNotFound if @link.nil?

      AccountingFirms::Unlink.call(link: @link, by: current_user)
      redirect_to accounting_firm_path, notice: t(".ended")
    end

    # Only while the new firm has no active administrator yet (RN-02-071).
    def resend_invitation
      authorize! :resend_invitation, @link || link_subject
      membership = pending_admins.find(params[:membership_id])
      @invitation = Invitations::Resend.call(membership: membership, channels: Array(params[:channels]),
        invited_by: current_user, brand: Current.brand)
      render :linked
    rescue ActiveRecord::RecordInvalid => error
      redirect_to accounting_firm_path, alert: error.record.errors.full_messages.to_sentence
    end

    private

    def load_link
      @link = AccountingFirmCompany.open.includes(:accounting_firm).find_by(company: Current.company)
    end

    # What new and create authorize: a link of the current company.
    def link_subject
      AccountingFirmCompany.new(company: Current.company)
    end

    def pending_admins
      return Membership.none unless @link&.active?

      firm_memberships = @link.accounting_firm.memberships
      return Membership.none if firm_memberships.active.with_role("firm_admin").exists?

      firm_memberships.invited.with_role("firm_admin").includes(:user)
    end

    def form_params
      permitted = params.fetch(:accounting_firm, {})
        .permit(:name, :cnpj, :admin_name, :admin_cpf, :admin_email, :admin_mobile_phone, channels: [])
      { channels: %w[email] }.merge(permitted.to_h.symbolize_keys) do |_key, default, given|
        given.is_a?(Array) ? given.compact_blank : given || default
      end
    end
  end
end

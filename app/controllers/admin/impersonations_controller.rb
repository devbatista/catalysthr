module Admin
  # Starting an impersonate (RN-02-080 to RN-02-082, D-185): find the person by CPF,
  # choose the brand where they have access, give the reason or ticket number, and open
  # the brand's subdomain with a one-time token.
  class ImpersonationsController < BaseController
    def new
      authorize! :create, ImpersonationSession
      @cpf = params[:cpf].to_s
      @user = User.where(platform_role: nil).find_by(cpf: Cpf.normalize(@cpf)) if Cpf.valid?(@cpf)
      @brands = @user ? brands_of(@user) : []
    end

    def create
      authorize! :create, ImpersonationSession
      user = User.where(platform_role: nil).find(params[:user_id])
      brand = brands_of(user).find { |candidate| candidate.id == params[:brand_id].to_i }
      impersonation, token = ImpersonationSession.issue!(impersonator: current_user, impersonated_user: user, brand: brand,
        reason: params[:reason].to_s.strip)
      redirect_to impersonation.brand.panel_url("/impersonation", token: token), allow_other_host: true
    rescue ActiveRecord::RecordInvalid => error
      redirect_to new_admin_impersonation_path(cpf: user&.cpf), alert: error.record.errors.full_messages.to_sentence
    end

    private

    # The brands where the person can sign in (RN-01-002).
    def brands_of(user)
      user.memberships.with_access.flat_map(&:access_brands).uniq
        .select { |brand| brand.active_subdomain && User.allowed_at(area: :panel, brand: brand).exists?(user.id) }
    end
  end
end

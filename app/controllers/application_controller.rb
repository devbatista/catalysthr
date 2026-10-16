class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # The session key of the running impersonate (RN-02-080).
  IMPERSONATION_KEY = "impersonation_session_id"
  # The session key of the support's running entry into a direct company (D-581).
  SUPPORT_ACCESS_KEY = "support_access_id"

  layout :area_layout

  # current_user is the person being seen; true_user is who is seeing (RN-02-080).
  impersonates :user

  before_action :set_host_context
  before_action :check_impersonation
  before_action :check_support_access
  # Who made each change in the trail (RN-05-010). PaperTrail no longer adds it by itself.
  before_action :set_paper_trail_whodunnit
  before_action :require_sign_in_feature
  before_action :check_area_access, if: :user_signed_in?
  # Wraps everything after it, so the actions' writes are undone (RN-02-084).
  around_action :simulate_writes, if: :simulated_request?

  helper_method :impersonating?

  # Every action authorizes through CanCanCan (RN-03-003, P-03-10). The test in
  # spec/requests/authorization_coverage_spec.rb fails for an action that does not.
  check_authorization unless: :devise_controller?

  rescue_from CanCan::AccessDenied, with: :forbidden

  # Actions open to anyone, such as the PWA manifest. Declared here so the
  # authorization coverage test knows them.
  class_attribute :public_action_names, instance_writer: false, default: [].freeze
  # Actions authorized by load_and_authorize_resource or authorize_resource.
  class_attribute :resource_authorization_options, instance_writer: false, default: [].freeze
  # Actions that only change the browser's session, such as choosing the current
  # company, and stay real during an impersonate.
  class_attribute :real_write_action_names, instance_writer: false, default: [].freeze

  def self.real_writes_during_impersonation(*actions)
    self.real_write_action_names = real_write_action_names + actions.map(&:to_s)
  end

  def self.public_actions(*actions)
    skip_authorization_check only: actions
    self.public_action_names = public_action_names + actions.map(&:to_s)
  end

  def self.load_and_authorize_resource(*args)
    super
    self.resource_authorization_options = resource_authorization_options + [ args.extract_options!.slice(:only, :except) ]
  end

  def self.authorize_resource(*args)
    super
    self.resource_authorization_options = resource_authorization_options + [ args.extract_options!.slice(:only, :except) ]
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, area: Current.area, brand: Current.brand, company: Current.company,
      support_access: Current.support_access)
  end

  private

  def set_host_context
    Current.area = request.env[HostResolver::AREA]
    Current.brand = Brand.find(request.env.fetch(HostResolver::BRAND_ID)) if Current.area == :panel
    Current.url_options = { host: request.host, protocol: request.protocol, port: request.optional_port }.compact
    Current.ip = request.remote_ip
    Current.user_agent = request.user_agent
    Current.request_id = request.request_id
  end

  # Extra columns of each PaperTrail version (RN-05-010).
  def info_for_paper_trail
    { ip: request.remote_ip, request_id: request.request_id, impersonator_id: Current.impersonation&.impersonator_id }
  end

  def impersonating?
    Current.impersonation.present?
  end

  # A running impersonate holds only while it is within its 30 minutes, at its brand,
  # with the same person on both ends (RN-02-081). Each request becomes an access event
  # (RN-02-088), written before the simulation so it is never undone.
  def check_impersonation
    impersonation_id = session[IMPERSONATION_KEY]
    return if impersonation_id.nil? && session[:impersonated_user_id].nil?

    # Checked before true_user, whose own session may have expired at the same time.
    impersonation = ImpersonationSession.find_by(id: impersonation_id)
    if impersonation&.running? && impersonation.brand_id == Current.brand&.id &&
        session[:impersonated_user_id] == impersonation.impersonated_user_id && true_user&.id == impersonation.impersonator_id
      Current.impersonation = impersonation
      AccessEvent.record!(kind: "impersonation", action: "request", user: impersonation.impersonated_user,
        subject: impersonation, metadata: { method: request.method, path: request.path })
    else
      end_impersonation(impersonation, :timeout)
      redirect_to PlatformUrl.admin("/impersonations/new"), allow_other_host: true, alert: t("impersonations.ended")
    end
  end

  # Ends the impersonate and signs the CatalystHR person out of the subdomain, where
  # they have no access of their own (RN-02-004).
  def end_impersonation(impersonation, reason)
    if impersonation&.ended_at.nil? && impersonation&.started_at
      impersonation.end!(reason)
      Current.impersonation = impersonation
      AccessEvent.record!(kind: "impersonation", action: "end", user: impersonation.impersonated_user, subject: impersonation,
        metadata: { reason: reason.to_s })
    end
    Current.impersonation = nil
    stop_impersonating_user
    session.delete(IMPERSONATION_KEY)
    # Without loading the user, whose own session may have expired.
    sign_out(:user)
  end

  # The support's entry holds while it is open, at its brand, for the same person, whose
  # own session ends after 30 minutes of inactivity (D-581, RN-02-050).
  def check_support_access
    access_id = session[SUPPORT_ACCESS_KEY]
    return if access_id.nil?

    access = SupportAccess.find_by(id: access_id)
    if access&.running? && access.brand_id == Current.brand&.id && current_user&.id == access.support_user_id
      Current.support_access = access
    else
      end_support_access(access, :timeout)
      redirect_to PlatformUrl.admin("/support-accesses/new"), allow_other_host: true, alert: t("support_accesses.ended")
    end
  end

  def end_support_access(access, reason)
    if access&.running?
      access.end!(reason)
      AccessEvent.record!(kind: "auth", action: "support_access_ended", user: access.support_user, subject: access,
        company: access.company, metadata: { reason: reason.to_s })
    end
    Current.support_access = nil
    session.delete(SUPPORT_ACCESS_KEY)
    sign_out(:user)
  end

  def simulated_request?
    impersonating? && !request.get? && !request.head? && !real_write_action_names.include?(action_name)
  end

  # The page shows "Simulação: nada foi salvo" (RN-02-084), also after a redirect.
  def simulate_writes(&)
    Simulation.run(&)
    flash[:simulation] = true if response.redirect?
  end

  def area_layout
    return "auth" if devise_controller?

    Current.area == :panel ? "panel" : "application"
  end

  # Until sign-in is released (P-20-11), the root shows the coming-soon page and every
  # other page answers 404.
  def require_sign_in_feature
    return if FeatureFlags.enabled?(FeatureFlags::SIGN_IN)

    if request.path == "/"
      render "#{Current.area}/home/coming_soon"
    else
      head :not_found
    end
  end

  # A session only lasts while the person may still sign in at this address: a
  # suspended or removed membership ends access at the next request (RN-02-063).
  def check_area_access
    # The support has no membership; its entry into the company is the access (D-581).
    return if Current.support_access
    return if User.allowed_at(area: Current.area, brand: Current.brand).exists?(current_user.id)

    sign_out(current_user)
    redirect_to new_user_session_path, alert: t("devise.failure.unauthenticated")
  end

  # People with a role that requires MFA set it up before anything else (RN-02-014,
  # item 3; RN-02-040; CA-02-006). Not during an impersonate: that is the person's own step.
  def require_mfa_setup
    return if impersonating?

    redirect_to new_account_mfa_path if !current_user.mfa_enabled? && current_user.mfa_required?
  end

  def after_sign_out_path_for(_scope)
    new_user_session_path
  end

  # RN-03-006: denied inside the scope answers 403. Outside the scope the record is
  # not found and the answer is 404 (RN-01-013).
  def forbidden
    render plain: t("authorization.forbidden"), status: :forbidden
  end
end

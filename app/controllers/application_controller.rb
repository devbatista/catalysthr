class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :area_layout

  before_action :set_host_context
  # Who made each change in the trail (RN-05-010). PaperTrail no longer adds it by itself.
  before_action :set_paper_trail_whodunnit
  before_action :require_sign_in_feature
  before_action :check_area_access, if: :user_signed_in?

  # Every action authorizes through CanCanCan (RN-03-003, P-03-10). The test in
  # spec/requests/authorization_coverage_spec.rb fails for an action that does not.
  check_authorization unless: :devise_controller?

  rescue_from CanCan::AccessDenied, with: :forbidden

  # Actions open to anyone, such as the PWA manifest. Declared here so the
  # authorization coverage test knows them.
  class_attribute :public_action_names, instance_writer: false, default: [].freeze
  # Actions authorized by load_and_authorize_resource or authorize_resource.
  class_attribute :resource_authorization_options, instance_writer: false, default: [].freeze

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
    @current_ability ||= Ability.new(current_user, area: Current.area)
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
    { ip: request.remote_ip, request_id: request.request_id }
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
    return if User.allowed_at(area: Current.area, brand: Current.brand).exists?(current_user.id)

    sign_out(current_user)
    redirect_to new_user_session_path, alert: t("devise.failure.unauthenticated")
  end

  # People with a role that requires MFA set it up before anything else (RN-02-014,
  # item 3; RN-02-040; CA-02-006).
  def require_mfa_setup
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

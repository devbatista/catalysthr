module Account
  class SecurityController < BaseController
    def show
      authorize! :manage, :own_security
      @sessions = current_user.user_sessions.active.includes(:brand).order(last_seen_at: :desc)
      @devices = current_user.trusted_devices.active.order(last_used_at: :desc)
    end
  end
end

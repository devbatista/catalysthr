# Seeing sensitive data asks for the password again, and the confirmation holds for 5
# minutes in the session (RN-02-052, D-183). A page shows a sensitive section only when
# asked (?reveal=section) and allowed; each value shown then becomes an access event
# (RN-05-001, RN-05-020), in SensitiveDataHelper. During an impersonate the password is
# not asked and the values stay masked (RN-02-087).
module SensitiveAccess
  extend ActiveSupport::Concern

  CONFIRMATION_KEY = "sensitive_confirmation"
  CONFIRMATION_VALIDITY = 5.minutes

  included do
    helper_method :revealed_sections, :sensitive_confirmed?
  end

  private

  def sensitive_confirmed?
    data = session[CONFIRMATION_KEY]
    data.is_a?(Hash) && data["user_id"] == current_user.id && data["at"].to_i > CONFIRMATION_VALIDITY.ago.to_i
  end

  def confirm_sensitive_access!
    session[CONFIRMATION_KEY] = { "user_id" => current_user.id, "at" => Time.current.to_i }
  end

  # The sections asked for, among the allowed ones. Without a recent confirmation, the
  # person goes to the password and comes back.
  def reveal_sections(allowed)
    @revealed_sections = Array(params[:reveal]).map(&:to_s) & allowed.map(&:to_s)
    require_sensitive_confirmation if @revealed_sections.any?
  end

  # For pages that always show sensitive values, such as forms that edit them.
  def reveal_all_sections(allowed)
    @revealed_sections = allowed.map(&:to_s)
    require_sensitive_confirmation if @revealed_sections.any?
  end

  def require_sensitive_confirmation
    return if impersonating? || sensitive_confirmed?

    redirect_to new_sensitive_confirmation_path(return_to: request.fullpath)
  end

  def revealed_sections
    @revealed_sections || []
  end
end

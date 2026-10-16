# The CatalystHR team in the admin area (spec 03, section 4.1). Inside companies the
# team acts through impersonation or, for support at direct companies, as a
# consultant (P-03-02, P-03-03).
class PlatformAbility
  include CanCan::Ability

  def initialize(user)
    return if user.platform_role.nil?

    can :read, :admin_home
    # The CatalystHR legal texts (D-579).
    can [ :read, :create ], LegalDocument, brand_id: nil if user.superadmin?
    # Seeing the system as a client's user (RN-02-080, D-185).
    can :create, ImpersonationSession if user.platform_role.in?(ImpersonationSession::IMPERSONATORS)
  end
end

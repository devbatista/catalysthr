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
  end
end

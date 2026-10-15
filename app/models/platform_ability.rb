# The CatalystHR team in the admin area (spec 03, section 4.1). Inside companies the
# team acts through impersonation or, for support at direct companies, as a
# consultant (P-03-02, P-03-03).
class PlatformAbility
  include CanCan::Ability

  def initialize(user)
    return if user.platform_role.nil?

    can :read, :admin_home
  end
end

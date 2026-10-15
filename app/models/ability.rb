# What a person may do (spec 03, RN-03-001, P-03-08): the sum of small partial
# abilities. The platform's applies in the admin area; the partner's, the company's
# and the accounting firm's apply in the brand's panel.
class Ability
  include CanCan::Ability

  def initialize(user, area:)
    return if user.nil?

    # Everyone manages the security of their own account (RN-02-042, RN-02-043, RN-02-053).
    can :manage, :own_security
    can :destroy, [ UserSession, TrustedDevice ], user_id: user.id

    case area
    when :admin
      merge(PlatformAbility.new(user))
    when :panel
      # Sign-in only accepts a membership in the brand (RN-01-002).
      can :read, :panel_home
      can :accept, :legal_documents
    end
  end
end

# What a person may do (spec 03, RN-03-001, P-03-08): the sum of small partial
# abilities. The platform's applies in the admin area; in the brand's panel, the
# partner's applies when the partner owns the subdomain, the accounting firm's when
# the firm serves a company of the brand, and the company's inside the current company.
class Ability
  include CanCan::Ability

  def initialize(user, area:, brand: nil, company: nil, support_access: nil)
    return if user.nil?

    # Everyone manages the security of their own account (RN-02-042, RN-02-043, RN-02-053).
    can :manage, :own_security
    can :destroy, [ UserSession, TrustedDevice ], user_id: user.id
    # Everyone reads their own notices (spec 15, section 6).
    can :read, Notification, recipient_user_id: user.id

    case area
    when :admin
      merge(PlatformAbility.new(user))
    when :panel
      # Sign-in only accepts a membership in the brand (RN-01-002).
      can :read, :panel_home
      can :accept, :legal_documents
      merge(PartnerAbility.new(user, brand.owner)) if brand&.owner.is_a?(Partner)
      merge(AccountingFirmAbility.new(user, brand)) if brand
      merge(CompanyAbility.new(user, company, support_access: support_access)) if company
    end
  end
end

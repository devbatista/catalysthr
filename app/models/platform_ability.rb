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
    # Entering a direct company as a consultant (D-581, P-03-02); the superadmin only sees
    # companies by impersonate (P-03-03).
    can :create, SupportAccess if user.support?
    # Brands of partners, direct companies and client companies, with the display mode;
    # only the superadmin changes a slug (spec 01, section 6, P-01-17).
    if user.superadmin? || user.support?
      can %i[read create update], Brand
      can :update_brand_display_mode, Company
    end
    can :change_slug, Brand if user.superadmin?
    # Moving a company between partners or to and from the direct modality (RN-01-050).
    can :create, CompanyTransfer if user.superadmin?
    # The e-mail domain of the brands that own a subdomain (spec 01, section 6, D-596).
    can :manage_email_domain, Brand, &:email_domain_configurable? if user.superadmin? || user.support?
    # Contact and MFA of the clients' users who also reach another organization (D-582).
    # Never of the CatalystHR team.
    can %i[read correct_contact reset_mfa release_email], User, platform_role: nil if user.superadmin? || user.support?
    # Plans, modules, add-ons and their prices (spec 03, section 4.1, D-115, RN-19-010).
    # Prices are never edited: a change is a new version (D-611).
    if user.superadmin? || user.finance?
      can %i[read create update], Plan
      can :create, PlanVersion
      can %i[read create], AddOnPrice
    end
  end
end

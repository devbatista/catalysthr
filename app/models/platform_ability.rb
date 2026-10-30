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
    # The feature flags, for everyone (RN-20-030, D-617).
    can %i[read update], :feature_flags if user.superadmin?
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
      can %i[read create], PreActivationPrice
      # Registering partners and direct companies, with trial or contract (RN-19-081).
      can %i[read create], BillingAccount
      # The invoices of every contract (spec 19, section 6, D-619).
      can :read, Invoice
      # Plan, modules, add-ons and price migration of a contract (RN-19-014, RN-19-060,
      # RN-19-061, D-620). The client's own changes come with block 19e.
      can :change_contract, BillingAccount
      # The contract's billing address, with the address by CEP (RN-19-103, D-635).
      can :update_billing_address, BillingAccount
      can :lookup, :address
      # Manual adjustments; above 20% of the next invoice, the finance team's wait for the
      # superadmin (RN-19-070, RN-19-071, D-621).
      can %i[read create cancel], BillingAdjustment
      can :approve, BillingAdjustment if user.superadmin?
      # Only the superadmin reactivates a contract in closing (RN-19-053, P-19-18, D-624).
      can :reactivate, BillingAccount if user.superadmin?
      # The NFS-e's fiscal settings and sending again a refused note (RN-19-102, RN-19-108,
      # D-633).
      can %i[read update], FiscalSetting
      can :reissue, ServiceInvoice
    end
    # The support reads the billing (spec 19, section 6).
    can :read, [ BillingAccount, Invoice, BillingAdjustment ] if user.support?
    # The team's panel: every block for the superadmin and the finance team, Clients for
    # the support (P-19-28). Phase 1 has only Revenue and Clients (D-610).
    can :read, %i[team_panel team_panel_clients]
    can :read, :team_panel_revenue if user.superadmin? || user.finance?
    # The holidays: the review of the national ones and the state and city ones by hand
    # (RN-11-020, P-11-06, D-336, D-638), in the admin's content (RN-19-080).
    can %i[read create update destroy review import], Holiday if user.superadmin? || user.support?
    # Sidekiq Web, for the superadmin and the support (RN-20-077).
    can :read, :sidekiq_web if user.superadmin? || user.support?
  end
end

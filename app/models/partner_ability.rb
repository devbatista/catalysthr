# What a person may do in the partner's panel (spec 03, section 4.1), by the roles of
# the active membership in the partner that owns the subdomain. The panel has no
# current company: companies are reached only through the portfolio (RN-01-011).
class PartnerAbility
  include CanCan::Ability

  # Roles the partner's administrator gives to the team (D-584).
  INVITABLE_ROLES = %w[partner_admin consultant].freeze

  def initialize(user, partner)
    membership = Membership.active.find_by(user: user, organization: partner)
    return if membership.nil?

    can :read, :partner_panel
    # The partner's models of process: the consultant reads them (spec 06, section 6).
    can :read, SharedProcessTemplate, partner_id: partner.id
    admin(user, partner) if membership.roles.include?("partner_admin")
  end

  private

  def admin(user, partner)
    team(user, partner)

    # The partner's brand and the client companies' own brands and display mode
    # (RN-01-034, D-165, D-166; spec 01, section 6).
    can %i[read update], Brand, owner_type: "Partner", owner_id: partner.id
    can %i[read create update], Brand, owner_type: "Company", owner_id: partner.companies.pluck(:id)
    can :update_brand_display_mode, Company, partner_id: partner.id
    # The client companies: register one with its first HR administrator (P-03-14) and
    # turn the contracted modules on or off for each (RN-19-012, D-616).
    can :create, Company, partner_id: partner.id
    can :manage_modules, Company, partner_id: partner.id
    # The portfolio's usage and its report by company (RN-19-024, spec 19, section 6), and
    # the contract's invoices, as its financial responsible (RN-19-044, D-619); and the
    # contracting during the trial or after it (RN-19-033, D-622).
    # The billing address, the NFS-e's customer at Asaas, with the address by CEP (D-635).
    can %i[read_usage read_invoices contract cancel_contract update_billing_address], Partner, id: partner.id
    can :lookup, :address
    # The partner's e-mail domain (spec 01, section 6, D-596). The client companies send
    # from it (P-01-18).
    can :manage_email_domain, Brand, owner_type: "Partner", owner_id: partner.id
    # The partner's models of process, and adopting the library's active ones (spec 06,
    # section 6, D-232).
    can %i[create update], SharedProcessTemplate, partner_id: partner.id
    can :adopt, SharedProcessTemplate, partner_id: nil, status: "active"

    # The HR administrators of the client companies: see, invite, change or remove them
    # (P-03-35, D-585). Never one's own membership (RN-03-012).
    can %i[read_hr_admin invite_hr_admin], Membership do |membership|
      client_hr_admin?(membership, partner)
    end
    can :change_hr_admin, Membership do |membership|
      client_hr_admin?(membership, partner) && membership.user_id != user.id
    end
  end

  def client_hr_admin?(membership, partner)
    membership.organization.is_a?(Company) && membership.organization.partner_id == partner.id &&
      membership.roles.include?("hr_admin")
  end

  # The partner's team: invite administrators and consultants, their roles, modules and
  # companies, and removal (D-052, P-03-06, D-584). Nobody changes their own access.
  def team(user, partner)
    can %i[read invite], Membership, organization_type: "Partner", organization_id: partner.id

    can %i[update revoke resend_invitation cancel_invitation], Membership do |membership|
      team_member?(membership, partner, user)
    end
    # Contact and MFA only for who has no access anywhere else (RN-02-044, P-02-17, D-582).
    can %i[correct_contact reset_mfa], Membership do |membership|
      team_member?(membership, partner, user) && membership.exclusive_access?
    end
  end

  def team_member?(membership, partner, user)
    membership.organization_type == "Partner" && membership.organization_id == partner.id && membership.user_id != user.id
  end
end

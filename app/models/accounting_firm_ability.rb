# What a person may do in an accounting firm's area (spec 02, RN-02-070 to RN-02-073;
# spec 03, section 4.2), by the roles of the active membership in a firm linked to a
# company of the current brand (D-586). Inside the companies, the accountants' reading
# comes with each module (payroll, admission forwarding).
class AccountingFirmAbility
  include CanCan::Ability

  # Roles the firm's administrator gives to the team (RN-02-071, D-584).
  INVITABLE_ROLES = %w[firm_admin accountant].freeze

  def initialize(user, brand)
    Membership.active.for_brand(brand).where(user: user, organization_type: "AccountingFirm").find_each do |membership|
      can :read, :firm_panel
      admin(user, membership.organization, brand) if membership.roles.include?("firm_admin")
      folders(membership.organization)
    end
  end

  private

  # The folders of the linked companies' people, read only and without health (spec 03,
  # section 4.5, D-193, P-03-18, CA-08-009). The screen comes with the admission's forward
  # (spec 07, D-642).
  def folders(firm)
    companies = AccountingFirmCompany.where(accounting_firm_id: firm.id, status: "active").pluck(:company_id)
    can :read, Document, company_id: companies, document_type: { category: DocumentCategory.readable(health: false, pay: true) }
  end

  def admin(user, firm, brand)
    # Requests from the brand's companies, accepted or refused by the firm (P-02-29, D-590).
    can %i[accept refuse], AccountingFirmCompany, accounting_firm_id: firm.id, status: "pending",
      company_id: brand.served_companies.pluck(:id)

    # The team: administrators and accountants (RN-02-071, D-584). Nobody changes their
    # own access.
    can %i[read invite], Membership, organization_type: "AccountingFirm", organization_id: firm.id
    can %i[update revoke resend_invitation cancel_invitation], Membership do |membership|
      team_member?(membership, firm, user)
    end
    # The MFA of the accountants, for who has no access elsewhere (RN-02-044, D-582).
    # Correcting the contact is not the firm's (spec 03, section 4.2).
    can :reset_mfa, Membership do |membership|
      team_member?(membership, firm, user) && membership.roles == [ "accountant" ] && membership.exclusive_access?
    end
  end

  def team_member?(membership, firm, user)
    membership.organization_type == "AccountingFirm" && membership.organization_id == firm.id && membership.user_id != user.id
  end
end

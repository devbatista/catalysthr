# What a person may do inside the current company (spec 03, section 4.2), by the roles
# of the membership there. A consultant of the company's partner, with the company
# assigned, acts as an HR analyst of all units (D-192), with the modules the partner
# released (P-03-06). The support entering a direct company acts the same way, with
# every module the company contracted (D-581, D-593). Listings use hash conditions, so accessible_by works
# (RN-03-002). A read-only membership (D-090) manages nothing (RN-03-004).
class CompanyAbility
  include CanCan::Ability

  # Roles the company's HR gives in this version: HR and managers (spec 03, section 4.2).
  # Employees come with the admission (spec 07) and client managers with the allocation
  # clients (spec 04).
  INVITABLE_ROLES = %w[hr_admin hr_analyst manager].freeze
  HR_ROLES = %w[hr_admin hr_analyst].freeze

  def initialize(user, company, support_access: nil)
    membership = Membership.with_access.find_by(user: user, organization: company)
    roles = membership.nil? || membership.read_only? ? [] : membership.roles
    # The HR analyst's rules come with the modules (spec 04 onwards, RN-03-005); the
    # consultant and the support get them through this role.
    roles += [ "hr_analyst" ] if consultant_of?(user, company) || support_at?(user, company, support_access)

    hr_admin(user, company) if roles.include?("hr_admin")
    hr_analyst(company) if roles.include?("hr_analyst")
  end

  private

  def support_at?(user, company, support_access)
    support_access&.running? && support_access.company_id == company.id && support_access.support_user_id == user.id
  end

  def consultant_of?(user, company)
    return false if company.direct?

    Membership.active.with_role("consultant").where(user: user, organization_type: "Partner", organization_id: company.partner_id)
      .joins(:partner_membership_companies).exists?(partner_membership_companies: { company_id: company.id })
  end

  # The HR analyst reads the units (spec 03, section 4.2); the U scope applies to the
  # people, from spec 04's block 4c.
  def hr_analyst(company)
    can :read, Unit, company_id: company.id
  end

  def hr_admin(user, company)
    # The company's settings and units (spec 03, section 4.2, D-601). The employer's
    # document is corrected only by the superadmin.
    can :update_settings, Company, id: company.id
    can %i[read create update], Unit, company_id: company.id
    can :lookup, :address

    can %i[read invite], Membership, organization_type: "Company", organization_id: company.id
    # The company's accounting firm: register or link it, resend the first invitation,
    # end the link (RN-02-070 to RN-02-073, D-588 to D-590).
    can %i[read link resend_invitation unlink], AccountingFirmCompany, company_id: company.id

    # Nobody changes their own access; another HR administrator does (RN-03-012).
    can %i[update revoke resend_invitation cancel_invitation], Membership do |membership|
      membership.organization == company && membership.user_id != user.id
    end

    # Contact of anyone in the company; the MFA of the HR (RN-02-044, P-02-17). Only for
    # who has no access anywhere else (D-582).
    can :correct_contact, Membership do |membership|
      membership.organization == company && membership.user_id != user.id && membership.exclusive_access?
    end
    can :reset_mfa, Membership do |membership|
      membership.organization == company && membership.user_id != user.id &&
        (membership.roles & HR_ROLES).any? && membership.exclusive_access?
    end
  end
end

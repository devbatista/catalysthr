# What a person may do inside the current company (spec 03, section 4.2), by the roles
# of the membership there. Listings use hash conditions, so accessible_by works
# (RN-03-002). A read-only membership (D-090) manages nothing (RN-03-004).
class CompanyAbility
  include CanCan::Ability

  # Roles the company's HR gives in this version: HR and managers (spec 03, section 4.2).
  # Employees come with the admission (spec 07) and client managers with the allocation
  # clients (spec 04).
  INVITABLE_ROLES = %w[hr_admin hr_analyst manager].freeze
  HR_ROLES = %w[hr_admin hr_analyst].freeze

  def initialize(user, company)
    membership = Membership.with_access.find_by(user: user, organization: company)
    return if membership.nil? || membership.read_only?

    hr_admin(user, company) if membership.roles.include?("hr_admin")
  end

  private

  def hr_admin(user, company)
    can :read, Membership, organization_type: "Company", organization_id: company.id
    can :invite, Membership

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

# What a person may do inside the current company (spec 03, section 4.2), by the roles
# of the membership there. A consultant of the company's partner, with the company
# assigned, acts as an HR analyst of all units (D-192), with the modules the partner
# released (P-03-06). The support entering a direct company acts the same way, with
# every module the company contracted (D-581, D-593). The released modules count only
# within the contracted ones (P-03-12, D-616). Listings use hash conditions, so accessible_by works
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
    contracted = company.contract_modules.releasable

    hr_admin(user, company) if roles.include?("hr_admin")
    if roles.include?("hr_analyst")
      hr_analyst(company, units: membership, modules: membership.enabled_modules & contracted)
    end
    # The consultant and the support act as an HR analyst of all units (D-192, D-581).
    if (consultant = consultant_membership(user, company))
      hr_analyst(company, units: :all, modules: consultant.enabled_modules & contracted)
    elsif support_at?(user, company, support_access)
      hr_analyst(company, units: :all, modules: contracted)
    end
    manager(company, membership) if roles.include?("manager")
    client_manager(company, membership) if roles.include?("client_manager")
    # A read-only membership still reads its modules (D-090).
    modules(membership&.roles || [], membership, consultant, support_at?(user, company, support_access), contracted)
  end

  private

  # The modules the person operates, which the menu shows (spec 03, section 2.3, D-191):
  # the HR analyst and the consultant only those released to them, the support every one
  # contracted; the HR administrator and the managers are not restricted (P-03-04).
  def modules(roles, membership, consultant, support, contracted)
    released = if (roles & %w[hr_admin manager client_manager]).any? then Membership::RELEASABLE_MODULES
    else
      [ (membership.enabled_modules if roles.include?("hr_analyst")), consultant&.enabled_modules, (contracted if support) ].flatten.compact
    end
    released.uniq.each { |code| can :use_module, code.to_sym }
  end

  def support_at?(user, company, support_access)
    support_access&.running? && support_access.company_id == company.id && support_access.support_user_id == user.id
  end

  def consultant_membership(user, company)
    return if company.direct?

    Membership.active.with_role("consultant").where(user: user, organization_type: "Partner", organization_id: company.partner_id)
      .joins(:partner_membership_companies).find_by(partner_membership_companies: { company_id: company.id })
  end

  # The HR analyst reads the units, departments and positions (spec 03, section 4.2), and
  # reads and edits the people of their units, the U scope (spec 03, section 4.3, D-142):
  # personal data, documents and health data (P-03-17), and salary and bank data only with
  # the payroll module (P-03-16). A past employment counts by its last unit.
  # units: the analyst's membership, whose units count, or :all.
  def hr_analyst(company, units:, modules:)
    can :read, [ Unit, Department, Position, AllocationClient ], company_id: company.id
    # The CEP for the person's address; the unit's position on the map is the HR
    # administrator's (D-216).
    can :lookup, :address

    people = { company_id: company.id }
    unless units == :all
      people[:id] = ActsAsTenant.with_tenant(company) do
        WorkerProfile.in_units(MembershipUnit.where(membership: units).select(:unit_id)).pluck(:id)
      end
    end
    can %i[read read_personal read_health update], WorkerProfile, people
    can :read_pay, WorkerProfile, people if modules.include?("folha")
  end

  # The manager reads their own departments, with the subdepartments (the E scope, D-190),
  # and those departments' units (spec 03, section 4.2), and the basic data of the people
  # with an open employment there.
  def manager(company, membership)
    department_ids, unit_ids = ActsAsTenant.with_tenant(company) do
      ids = Department.team_ids_for(membership)
      [ ids, Department.where(id: ids).distinct.pluck(:unit_id) ]
    end
    can :read, Department, company_id: company.id, id: department_ids
    can :read, Unit, company_id: company.id, id: unit_ids
    # The team's basic data only (spec 03, section 4.3).
    team = ActsAsTenant.with_tenant(company) { WorkerProfile.in_departments(department_ids).pluck(:id) }
    can :read, WorkerProfile, company_id: company.id, id: team
  end

  # The client manager reads the basic data of the people allocated in their active
  # clients, the K scope (spec 03, section 4.12, RN-04-095, P-03-38 to P-03-40). Nothing
  # while the company does not use allocation clients.
  def client_manager(company, membership)
    return unless company.uses_allocation_clients

    people = ActsAsTenant.with_tenant(company) do
      clients = AllocationClientManager.joins(:allocation_client)
        .where(membership: membership, allocation_clients: { status: "active" }).select(:allocation_client_id)
      WorkerProfile.in_allocation_clients(clients).pluck(:id)
    end
    can :read, WorkerProfile, company_id: company.id, id: people
  end

  def hr_admin(user, company)
    # The company's settings and units (spec 03, section 4.2, D-601). The employer's
    # document is corrected only by the superadmin.
    can :update_settings, Company, id: company.id
    # The direct company's invoices and its contracting during the trial or after it, as
    # its financial responsible (RN-19-033, RN-19-044, D-619, D-622). A
    # partner's company has no contract of its own (RN-19-001).
    can %i[read_invoices contract cancel_contract], Company, id: company.id if company.direct?
    can %i[read create update], [ Unit, Department, Position ], company_id: company.id
    can %i[lookup geocode], :address
    can :lookup, :cbo
    # Every person of the company (spec 03, section 4.3). Only the HR administrator
    # registers someone by hand for now (D-600); the admission comes with spec 07.
    can %i[read read_personal read_health read_pay update create], WorkerProfile, company_id: company.id
    # Custom fields and allocation clients, with their managers (RN-04-080, RN-04-090,
    # RN-04-094, RN-02-064, D-605).
    can %i[read create update], CustomFieldDefinition, company_id: company.id
    can %i[read create update], AllocationClient, company_id: company.id
    can :manage_managers, AllocationClient, company_id: company.id

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

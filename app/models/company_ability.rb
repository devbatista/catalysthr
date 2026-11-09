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

  # The units whose notices of the board the person sees in the panel and may choose, or
  # :all (P-15-22, D-656).
  attr_reader :announcement_unit_ids

  # The units of the HR panel's numbers (RN-17-001, RN-17-014): :all for the HR
  # administrator, the consultant and the support, the HR analyst's own units, or nil for who
  # has no HR panel.
  attr_reader :hr_unit_ids

  def initialize(user, company, support_access: nil)
    @user = user
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
    announcements(user, company, membership, roles, reader: consultant || support_at?(user, company, support_access))
    manager(company, membership) if roles.include?("manager")
    employee(company, membership) if roles.include?("employee")
    # The portal (spec 16, RN-16-002, D-645): the employee and the manager.
    can :read, :portal if (roles & %w[employee manager]).any?
    client_manager(company, membership) if roles.include?("client_manager")
    assigned_items(company, membership) if (roles & %w[manager client_manager]).any?
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

  # The board of notices (RN-15-070, P-15-22, D-656): the HR administrator publishes to the
  # whole company and the HR analyst to their units; each edits and withdraws their own, the
  # HR administrator any. Who published and the HR administrator see how many opened it
  # (spec 15, section 6). The consultant and the support only read it (D-656). The employee
  # reads it in the portal, by the audience.
  def announcements(user, company, membership, roles, reader:)
    if roles.include?("hr_admin")
      @announcement_unit_ids = :all
      can %i[read create update withdraw read_reads], Announcement, company_id: company.id
    elsif roles.include?("hr_analyst")
      @announcement_unit_ids = ActsAsTenant.with_tenant(company) { MembershipUnit.where(membership: membership).pluck(:unit_id) }
      can :read, Announcement, company_id: company.id
      can :create, Announcement, company_id: company.id if @announcement_unit_ids.any?
      can %i[update withdraw read_reads], Announcement, company_id: company.id, author_id: user.id
    elsif reader
      @announcement_unit_ids = :all
      can :read, Announcement, company_id: company.id
    end
    can :read_board, Announcement if roles.include?("employee")
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
    can :read, [ Unit, UnitHoliday, Department, Position, AllocationClient ], company_id: company.id
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
    unit_ids = units == :all ? :all : ActsAsTenant.with_tenant(company) { MembershipUnit.where(membership: units).pluck(:unit_id) }
    hr_dashboard(unit_ids)
    processes(company, unit_ids: unit_ids, modules: modules)
    admissions(company, unit_ids: unit_ids) if modules.include?("admissao")
    admission_documents(company, unit_ids) if modules.include?("admissao") && !modules.include?("documentos")
    if modules.include?("documentos")
      folders = { company_id: company.id }
      folders[:worker_profile_id] = people[:id] if people.key?(:id)
      documents(folders, pay: modules.include?("folha"))
    end
  end

  # The HR panel (spec 17, section 6): the HR administrator with the whole company, the HR
  # analyst, the consultant and the support with their units (RN-17-014). A person with more
  # than one of these keeps the widest.
  def hr_dashboard(unit_ids)
    can :read, :hr_dashboard
    @hr_unit_ids = if unit_ids == :all || @hr_unit_ids == :all then :all
    else
      (Array(@hr_unit_ids) + unit_ids).uniq
    end
  end

  # The folders the HR reaches (spec 03, section 4.5, D-642): see, send and review, health
  # included (P-03-17), and the payroll's category only with the payroll module (P-03-16).
  # Deleting is the HR administrator's, with block 08c (P-03-19).
  def documents(folders, pay:)
    can %i[read upload review], Document, folders.merge(document_type: { category: DocumentCategory.readable(health: true, pay: pay) })
    # Requests and publications asking for an acknowledgment, to the people of their scope
    # (RN-08-040, RN-08-050, D-643); each panel shows only those people.
    can %i[read create], [ DocumentRequest, DocumentPublication ], company_id: folders[:company_id]
    can :refuse, Acknowledgment, folders
    # The batches of who sent them (RN-08-060, D-644) and the folder's ZIP of who asked it
    # (RN-08-082, D-642).
    can %i[read create update], DocumentBatch, company_id: folders[:company_id], uploaded_by_id: @user.id
    can :export, WorkerProfile, folders.slice(:company_id).merge(folders.key?(:worker_profile_id) ? { id: folders[:worker_profile_id] } : {})
    can :download, DocumentFolderExport, company_id: folders[:company_id], requested_by_id: @user.id
  end

  # The processes the HR runs (spec 03, sections 4.4 and 4.6, D-641): those of their units,
  # with the kind's module; every one for the HR administrator. :adjust is the HR's part:
  # change, skip, end, cancel and the history (RN-06-051 to RN-06-053).
  def processes(company, unit_ids:, modules:)
    kinds = ProcessInstance::MODULES.select { |_kind, code| modules == :all || modules.include?(code) }.keys
    conditions = { company_id: company.id, kind: kinds }
    conditions[:unit_id] = unit_ids unless unit_ids == :all
    can %i[read adjust], ProcessInstance, conditions
    can :act, ProcessItem, company_id: company.id, instance: conditions
  end

  # The admissions the HR runs (spec 03, section 4.4, spec 07, section 6): those of their
  # units; every one for the HR administrator. :admit_in says in which units a new one starts
  # (the U scope). :read_summary is what the client manager also has: the step, the status,
  # the date and their own items (P-07-20).
  def admissions(company, unit_ids:)
    instances = { kind: "admission" }
    units = { company_id: company.id }
    unless unit_ids == :all
      instances[:unit_id] = unit_ids
      units[:id] = unit_ids
    end
    can %i[read read_summary create update release], Admission, company_id: company.id, process_instance: instances
    can :admit_in, Unit, units
  end

  # Who runs an admission sends and reviews that person's documents without the documents
  # module, only while it's open and in their units (spec 03, section 4.4, D-650).
  def admission_documents(company, unit_ids)
    people = ActsAsTenant.with_tenant(company) do
      open = Admission.in_status("open")
      open = open.where(process_instances: { unit_id: unit_ids }) unless unit_ids == :all
      open.joins(:employment).pluck("employments.worker_profile_id")
    end
    can %i[read upload review], Document, company_id: company.id, worker_profile_id: people,
      document_type: { category: DocumentCategory::ALL }
  end

  # The manager and the client manager see and resolve only the items assigned to them
  # (spec 03, sections 4.4 and 4.12, RN-03-014, P-03-39).
  def assigned_items(company, membership)
    instance_ids, item_ids = ActsAsTenant.with_tenant(company) do
      items = ProcessItem.where("? = ANY(responsible_membership_ids)", membership.id)
      [ items.distinct.pluck(:process_instance_id), items.pluck(:id) ]
    end
    can :read, ProcessInstance, company_id: company.id, id: instance_ids
    can :act, ProcessItem, company_id: company.id, id: item_ids
  end

  # What the employee does in the portal with their own folder and items (spec 16, D-645):
  # see the documents in force, never the internal types (D-274, D-280), send them and new
  # versions, confirm an acknowledgment (RN-08-051), and resolve the process items assigned
  # to them. Health is only read (spec 03, section 4.5). Its own actions, so none of the
  # HR's panel opens to them.
  def employee(company, membership)
    profile_id = ActsAsTenant.with_tenant(company) { WorkerProfile.where(membership: membership).pick(:id) }
    return unless profile_id

    own = { company_id: company.id, worker_profile_id: profile_id }
    can :read_own, Document, own.merge(document_type: { internal: false })
    can :upload_own, Document, own.merge(document_type: { internal: false, category: DocumentCategory::ALL - %w[health] })
    can :acknowledge, Acknowledgment, own
    item_ids = ActsAsTenant.with_tenant(company) { ProcessItem.where("? = ANY(responsible_membership_ids)", membership.id).pluck(:id) }
    can :complete_own, ProcessItem, company_id: company.id, id: item_ids
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
    # The manager's panel, only the team (spec 17, RN-17-020, D-190).
    can :read, :manager_dashboard
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
    can :read_summary, Admission, company_id: company.id, employment: { worker_profile_id: people }
  end

  def hr_admin(user, company)
    # The company's settings and units (spec 03, section 4.2, D-601). The employer's
    # document is corrected only by the superadmin.
    can :update_settings, Company, id: company.id
    # The direct company's invoices and its contracting during the trial or after it, as
    # its financial responsible (RN-19-033, RN-19-044, D-619, D-622). A
    # partner's company has no contract of its own (RN-19-001).
    # The billing address, the NFS-e's customer at Asaas (D-635).
    can %i[read_invoices contract cancel_contract update_billing_address], Company, id: company.id if company.direct?
    can %i[read create update], [ Unit, Department, Position ], company_id: company.id
    hr_dashboard(:all)
    # The implementation's imports (spec 18, RN-18-042, D-661, D-663): only the HR
    # administrator, and the support through the assisted import (block 18d). The people,
    # their dependents and their accounts, as the manual registration (D-600).
    can %i[read create confirm cancel download_errors], DataImport, company_id: company.id
    can :import, %i[structure employees dependents bank_accounts]
    # The company's usage on the panel (RN-17-030, RN-17-031): with the contract and its
    # billing in a direct company, only the company's own usage in a partner's.
    can :read_usage, Company, id: company.id
    # The unit's holidays and optional days, and turning off Good Friday (RN-06-029, D-638).
    can %i[read create destroy], UnitHoliday, company_id: company.id
    # The company's models of process, and adopting the active ones of its partner and of
    # the library (spec 06, section 6, D-240, P-06-01, P-06-02).
    can %i[read create update], ProcessTemplate, company_id: company.id
    can :adopt, SharedProcessTemplate, partner_id: [ nil, company.partner_id ].uniq, status: "active"
    processes(company, unit_ids: :all, modules: :all)
    admissions(company, unit_ids: :all)
    # The models of contracts and terms (P-07-17).
    can %i[read create update], DocumentTemplate, company_id: company.id
    # The company's document types, and turning off or adjusting the platform's (RN-08-002,
    # RN-08-004, D-272).
    can %i[read create update configure_expiration], DocumentType, company_id: company.id
    can %i[read configure configure_expiration], DocumentType, company_id: nil
    documents({ company_id: company.id }, pay: true)
    # Deleting and recovering a document are the HR administrator's (P-03-19, RN-08-083).
    can %i[destroy restore], Document, company_id: company.id
    can %i[lookup geocode], :address
    can :lookup, :cbo
    # Every person of the company (spec 03, section 4.3). Only the HR administrator
    # registers by hand who already works there (D-600).
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

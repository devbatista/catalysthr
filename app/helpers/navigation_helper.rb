# The sidebar's menus (D-597): the company's, the partner's, the accounting firm's and the
# admin's. An item appears only when the person may open it; the prototype's modules not
# built yet are listed with "Em breve" (ComingSoon).
module NavigationHelper
  NavGroup = Data.define(:label, :items)
  NavItem = Data.define(:label, :path, :active, :tag)

  # Where the person is in the brand's panel: the partner's or the accounting firm's area,
  # a company, or none yet (the company chooser).
  def panel_context
    if controller_path.start_with?("panel/partner_panel")
      :partner
    elsif controller_path.start_with?("panel/firm_panel")
      :firm
    elsif Current.company
      :company
    end
  end

  # The organization of the area the person is in: the partner, the accounting firm or the
  # current company.
  def area_organization_name
    case panel_context
    when :partner then partner_membership&.organization&.name
    when :firm then firm_membership&.organization&.name
    else Current.company&.name
    end
  end

  def panel_navigation
    groups = case panel_context
    when :partner then partner_navigation
    when :firm then firm_navigation
    when :company then company_navigation
    else chooser_navigation
    end
    compact_navigation(groups + [ other_areas_group ])
  end

  def admin_navigation
    compact_navigation([
      nav_group(:platform, [
        nav_item(t("navigation.home"), admin_root_path, controller_path == "admin/home"),
        (nav_item(t("navigation.brands"), admin_brands_path, controller_path.in?(%w[admin/brands admin/company_brands admin/brand_email_domains])) if can?(:read, Brand)),
        (nav_item(t("navigation.admin_users"), admin_users_path, controller_path == "admin/users") if can?(:read, User.new)),
        (nav_item(t("navigation.company_transfer"), new_admin_company_transfer_path, controller_path == "admin/company_transfers") if company_transfer_allowed?),
        (nav_item(t("navigation.feature_flags"), admin_feature_flags_path, controller_path == "admin/feature_flags") if can?(:read, :feature_flags)),
        (nav_item(t("navigation.sidekiq"), admin_sidekiq_web_path, false) if can?(:read, :sidekiq_web))
      ]),
      nav_group(:billing, [
        (nav_item(t("navigation.dashboard"), admin_dashboard_path, controller_path == "admin/dashboards") if billing_allowed?(:team_panel)),
        (nav_item(t("navigation.clients"), admin_clients_path, controller_path == "admin/billing_accounts") if billing_allowed?(BillingAccount)),
        (nav_item(t("navigation.invoices"), admin_invoices_path, controller_path == "admin/invoices") if billing_allowed?(Invoice)),
        (nav_item(t("navigation.adjustments"), admin_adjustments_path, controller_path == "admin/billing_adjustments") if billing_allowed?(BillingAdjustment)),
        (nav_item(t("navigation.plans"), admin_plans_path,
          controller_path.in?(%w[admin/plans admin/plan_versions admin/add_on_prices admin/pre_activation_prices])) if billing_allowed?(Plan)),
        (nav_item(t("navigation.fiscal_settings"), admin_fiscal_settings_path, controller_path == "admin/fiscal_settings") if nfse_allowed?)
      ]),
      # The content every company uses (RN-19-080): for now, the holidays (D-638).
      nav_group(:content, [
        (nav_item(t("navigation.process_library"), admin_process_templates_path,
          controller_path.in?(%w[admin/process_templates admin/process_template_items])) if can?(:read, SharedProcessTemplate)),
        (nav_item(t("navigation.holidays"), admin_holidays_path, controller_path == "admin/holidays") if can?(:read, Holiday))
      ]),
      nav_group(:support, [
        (nav_item(t("navigation.impersonate"), new_admin_impersonation_path, controller_path == "admin/impersonations") if can?(:create, ImpersonationSession)),
        (nav_item(t("navigation.support_access"), new_admin_support_access_path, controller_path == "admin/support_accesses") if can?(:create, SupportAccess))
      ]),
      nav_group(:legal, [
        (nav_item(t("navigation.legal_documents"), admin_legal_documents_path, controller_path == "admin/legal_documents") if can?(:read, LegalDocument))
      ])
    ])
  end

  # The person's initials for the avatar.
  def initials(name)
    name.to_s.split.values_at(0, -1).compact.uniq.map { |part| part[0] }.join.upcase
  end

  private

  def company_transfer_allowed?
    FeatureFlags.enabled?(FeatureFlags::COMPANY_TRANSFER) && can?(:create, CompanyTransfer)
  end

  def billing_allowed?(action = :read, subject)
    FeatureFlags.enabled?(FeatureFlags::BILLING) && can?(action, subject)
  end

  # The NFS-e's screens, behind their own flag (D-633).
  def nfse_allowed?
    FeatureFlags.enabled?(FeatureFlags::NFSE) && billing_allowed?(FiscalSetting)
  end

  # "Contratar", while the contract is in its trial or in the 30 days after it (RN-19-033).
  def checkout_allowed?(owner)
    billing_allowed?(:contract, owner) && Billing::Checkout.open?(owner.billing_account&.subscription)
  end

  def client_manager_only?
    Membership.with_access.find_by(user: current_user, organization: Current.company)&.roles == %w[client_manager]
  end

  EMPLOYEE_CONTROLLERS = %w[panel/employees panel/employments panel/employment_revisions panel/emergency_contacts
    panel/dependents panel/bank_accounts].freeze

  def company_navigation
    company = Current.company
    # The client manager sees only what is theirs, without the modules to come (P-03-39).
    soon = client_manager_only? ? {} : ComingSoon::COMPANY_GROUPS
    # A contracted module shows only when the company has it (D-616).
    groups = soon.to_h do |group, features|
      items = features.filter_map do |feature|
        state = ComingSoon.state(feature, company)
        soon_item(feature, coming_soon_path(feature), state) if state && ComingSoon.released?(feature, current_ability)
      end
      [ group, items ]
    end
    groups[:operation] ||= []
    groups[:operation].unshift(
      nav_item(t("navigation.home"), root_path, controller_path == "panel/home"),
      (nav_item(t("navigation.employees"), employees_path, controller_path.in?(EMPLOYEE_CONTROLLERS)) if can?(:read, WorkerProfile))
    )

    groups.map { |group, items| nav_group(group, items) } + [
      nav_group(:company, [
        (nav_item(t("navigation.users"), memberships_path, controller_path == "panel/memberships") if can?(:read, Membership.new(organization: company))),
        (nav_item(t("navigation.units"), units_path, controller_path == "panel/units") if can?(:read, Unit)),
        (nav_item(t("navigation.departments"), departments_path, controller_path == "panel/departments") if can?(:read, Department)),
        (nav_item(t("navigation.positions"), positions_path, controller_path == "panel/positions") if can?(:read, Position)),
        (nav_item(t("navigation.allocation_clients"), allocation_clients_path, controller_path == "panel/allocation_clients") if company.uses_allocation_clients && can?(:read, AllocationClient)),
        (nav_item(t("navigation.custom_fields"), custom_fields_path, controller_path == "panel/custom_fields") if can?(:read, CustomFieldDefinition)),
        (nav_item(t("navigation.process_templates"), process_templates_path,
          controller_path.in?(%w[panel/process_templates panel/process_template_items])) if can?(:read, ProcessTemplate)),
        (nav_item(t("navigation.accounting_firm"), accounting_firm_path, controller_path == "panel/accounting_firms") if can?(:read, AccountingFirmCompany.new(company: company))),
        (nav_item(t("navigation.contract"), new_contract_path, controller_path == "panel/contracts") if checkout_allowed?(company)),
        (nav_item(t("navigation.invoices"), invoices_path, controller_path == "panel/invoices") if billing_allowed?(:read_invoices, company)),
        (nav_item(t("navigation.settings"), edit_company_settings_path, controller_path == "panel/company_settings") if can?(:update_settings, company))
      ])
    ]
  end

  def partner_navigation
    partner = partner_membership&.organization
    return [] unless partner

    [
      nav_group(:partner, [
        nav_item(t("navigation.portfolio"), partner_root_path,
          controller_path.in?(%w[panel/partner_panel/home panel/partner_panel/company_brands panel/partner_panel/company_hr_admins])),
        (nav_item(t("navigation.usage"), partner_usage_path, controller_path == "panel/partner_panel/usages") if billing_allowed?(:read_usage, partner)),
        (nav_item(t("navigation.contract"), new_partner_contract_path, controller_path == "panel/partner_panel/contracts") if checkout_allowed?(partner)),
        (nav_item(t("navigation.invoices"), partner_invoices_path, controller_path == "panel/partner_panel/invoices") if billing_allowed?(:read_invoices, partner)),
        (nav_item(t("navigation.team"), partner_team_members_path, controller_path == "panel/partner_panel/team_members") if can?(:read, Membership.new(organization: partner))),
        (nav_item(t("navigation.brand"), edit_partner_brand_path, controller_path.in?(%w[panel/partner_panel/brands panel/partner_panel/brand_email_domains])) if partner.brand && can?(:update, partner.brand)),
        (nav_item(t("navigation.process_templates"), partner_process_templates_path,
          controller_path.in?(%w[panel/partner_panel/process_templates panel/partner_panel/process_template_items])) if can?(:read, SharedProcessTemplate))
      ])
    ]
  end

  def firm_navigation
    firm = firm_membership&.organization
    return [] unless firm

    [
      nav_group(:firm, [
        nav_item(t("navigation.firm_companies"), firm_root_path, controller_path.in?(%w[panel/firm_panel/home panel/firm_panel/links])),
        (nav_item(t("navigation.team"), firm_team_members_path, controller_path == "panel/firm_panel/team_members") if can?(:read, Membership.new(organization: firm)))
      ])
    ]
  end

  def chooser_navigation
    [ nav_group(:company, [ nav_item(t("navigation.companies"), companies_path, controller_path == "panel/companies") ]) ]
  end

  # The person's other areas on this subdomain.
  def other_areas_group
    nav_group(:areas, [
      (nav_item(t("navigation.partner_area"), partner_root_path, false) if panel_context != :partner && can?(:read, :partner_panel)),
      (nav_item(t("navigation.firm_area"), firm_root_path, false) if panel_context != :firm && can?(:read, :firm_panel))
    ])
  end

  # state: :soon, or :after_contract for a module that waits for the contract (D-616).
  def soon_item(feature, path, state = :soon)
    active = controller_name == "coming_soon" && params[:feature] == feature
    NavItem.new(label: t(ComingSoon.translation_key(feature)), path: path, active: active, tag: t("navigation.tags.#{state}"))
  end

  def nav_item(label, path, active)
    NavItem.new(label: label, path: path, active: active, tag: nil)
  end

  def nav_group(key, items)
    NavGroup.new(label: t("navigation.groups.#{key}"), items: items.compact)
  end

  def compact_navigation(groups)
    groups.reject { |group| group.items.empty? }
  end
end

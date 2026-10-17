# The sidebar's menus (D-597): the company's, the partner's, the accounting firm's and the
# admin's. An item appears only when the person may open it; the prototype's modules not
# built yet are listed with "Em breve" (ComingSoon).
module NavigationHelper
  NavGroup = Data.define(:label, :items)
  NavItem = Data.define(:label, :path, :active, :soon)

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
        (nav_item(t("navigation.company_transfer"), new_admin_company_transfer_path, controller_path == "admin/company_transfers") if company_transfer_allowed?)
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

  def company_navigation
    company = Current.company
    groups = ComingSoon::COMPANY_GROUPS.to_h do |group, features|
      [ group, features.map { |feature| soon_item(feature, coming_soon_path(feature)) } ]
    end
    groups[:operation].unshift(nav_item(t("navigation.home"), root_path, controller_path == "panel/home"))

    groups.map { |group, items| nav_group(group, items) } + [
      nav_group(:company, [
        (nav_item(t("navigation.users"), memberships_path, controller_path == "panel/memberships") if can?(:read, Membership.new(organization: company))),
        (nav_item(t("navigation.accounting_firm"), accounting_firm_path, controller_path == "panel/accounting_firms") if can?(:read, AccountingFirmCompany.new(company: company)))
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
        (nav_item(t("navigation.team"), partner_team_members_path, controller_path == "panel/partner_panel/team_members") if can?(:read, Membership.new(organization: partner))),
        (nav_item(t("navigation.brand"), edit_partner_brand_path, controller_path.in?(%w[panel/partner_panel/brands panel/partner_panel/brand_email_domains])) if partner.brand && can?(:update, partner.brand)),
        *ComingSoon::PARTNER_FEATURES.map { |feature| soon_item(feature, partner_coming_soon_path(feature)) }
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

  def soon_item(feature, path)
    active = controller_name == "coming_soon" && params[:feature] == feature
    NavItem.new(label: t(ComingSoon.translation_key(feature)), path: path, active: active, soon: true)
  end

  def nav_item(label, path, active)
    NavItem.new(label: label, path: path, active: active, soon: false)
  end

  def nav_group(key, items)
    NavGroup.new(label: t("navigation.groups.#{key}"), items: items.compact)
  end

  def compact_navigation(groups)
    groups.reject { |group| group.items.empty? }
  end
end

# The only place where data of more than one company is read (RN-01-011, P-01-06).
# Views without a current company (the partner's panel, the admin area) pass the
# companies the person may see; the tenant is switched off only here, and the query is
# always narrowed to those companies. Calling ActsAsTenant.without_tenant anywhere else
# breaks spec/models/cross_company_spec.rb.
module CrossCompany
  module_function

  # The companies of the brand's partner a person reaches without a current company:
  # all of them for the partner's administrator, the assigned ones for the consultant
  # (D-052).
  def companies_for(user, brand:)
    partner = brand&.owner
    return Company.none unless partner.is_a?(Partner)

    Membership.active.find_by(user: user, organization: partner)&.portfolio_companies || Company.none
  end

  # Records of a company-owned model across the given companies, built with the tenant
  # switched off and narrowed to them.
  def scope(model, companies)
    raise ArgumentError, "#{model} is not company-owned" unless model.respond_to?(:scoped_by_tenant?) && model.scoped_by_tenant?

    ActsAsTenant.without_tenant { model.where(company_id: companies.select(:id)) }
  end
end

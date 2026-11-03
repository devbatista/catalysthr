module Processes
  # The HR that answers for a process (spec 03, D-192, D-641): the company's HR
  # administrators; the HR analysts of the unit with the kind's module; and the partner's
  # consultants assigned to the company with that module.
  class HrScope
    def initialize(company)
      @company = company
    end

    # modul: the module the analysts and the consultants need, the kind's by default; the
    # documents' notices ask for "documentos" (D-643).
    def memberships_for(unit_id:, kind: nil, modul: ProcessInstance::MODULES.fetch(kind))
      company_hr = Membership.with_access.where(organization: @company).includes(:user).to_a
      admins = company_hr.select { |membership| membership.roles.include?("hr_admin") }
      analysts = company_hr.select do |membership|
        membership.roles.include?("hr_analyst") && !membership.roles.include?("hr_admin") && membership.enabled_modules.include?(modul)
      end
      analyst_units = MembershipUnit.where(membership: analysts).pluck(:membership_id, :unit_id)
      analysts = analysts.select { |membership| analyst_units.include?([ membership.id, unit_id ]) }
      admins + analysts + consultants(modul)
    end

    private

    def consultants(modul)
      return [] if @company.direct?

      Membership.with_access.with_role("consultant").where(organization_type: "Partner", organization_id: @company.partner_id)
        .joins(:partner_membership_companies).where(partner_membership_companies: { company_id: @company.id }).includes(:user)
        .select { |membership| membership.enabled_modules.include?(modul) }
    end
  end
end

module Memberships
  # The partner's companies assigned to a consultant (D-052). Only the partner's own
  # companies count, and without the consultant role there are none. A company taken
  # away stops being reachable at the next request (RN-01-005).
  class AssignCompanies
    def self.call(**)
      new(**).call
    end

    def initialize(membership:, company_ids:, by:)
      @membership = membership
      @company_ids = Array(company_ids).compact_blank
      @by = by
    end

    def call
      wanted = @membership.roles.include?("consultant") ? @membership.organization.companies.where(id: @company_ids).pluck(:id) : []
      current = @membership.partner_membership_companies.pluck(:company_id)
      return @membership if wanted.sort == current.sort

      Membership.transaction do
        @membership.partner_membership_companies.where(company_id: current - wanted).destroy_all
        (wanted - current).each { |company_id| @membership.partner_membership_companies.create!(company_id: company_id) }
      end
      AccessEvent.record!(kind: "admin", action: "companies_assigned", user: @by, subject: @membership,
        metadata: { from: current.sort, to: wanted.sort })
      @membership
    end
  end
end

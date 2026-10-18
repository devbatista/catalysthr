module Employments
  # Every morning, tells the HR about the revisions that come into force on the day
  # (P-04-29, D-602, D-608). The revision in force is already chosen by its date
  # (RN-04-061), so the job only notifies; the eSocial pending items come with spec 13.
  # Each HR person gets one notice with the revisions of their scope: the administrator
  # all of them, the analyst those in their units (D-142), and the partner's consultant
  # with the company assigned all of them (D-192). Only names and reasons, never the salary
  # (RN-15-005). The admission revision is the employment's start, not a change. Runs
  # again without repeating: one notice per person, company and day (RN-15-085).
  class ApplyScheduledRevisionsJob < ApplicationJob
    queue_as :default

    # Names written out in the notice; the rest is counted.
    NAMES_SHOWN = 3

    def perform(date = Date.current)
      company_ids = CrossCompany.scope(EmploymentRevision, Company.all).where(effective_on: date).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) { notify_company(company, date) }
      end
    end

    private

    def due(date)
      EmploymentRevision.where(effective_on: date).where.not(reason: "admission")
        .where(employment_id: Employment.where(status: Employment::OPEN_STATUSES).select(:id))
    end

    # One line per employment: the revision registered last prevails on the same date (D-603).
    def notify_company(company, date)
      revisions = due(date).includes(employment: { worker_profile: :user }).order(:created_at, :id)
        .group_by(&:employment_id).values.map(&:last)
      return if revisions.empty?

      recipients(company).each do |membership, unit_ids|
        mine = unit_ids ? revisions.select { |revision| unit_ids.include?(revision.unit_id) } : revisions
        notify(company, membership, mine, date) if mine.any?
      end
    end

    # [membership, unit ids or nil for all units]
    def recipients(company)
      memberships = Membership.active.where(organization: company).includes(:user).to_a
      admins = memberships.select { |membership| membership.roles.include?("hr_admin") }.map { |membership| [ membership, nil ] }
      analysts = memberships.select { |membership| membership.roles.include?("hr_analyst") && !membership.roles.include?("hr_admin") }
      units = MembershipUnit.where(membership: analysts).pluck(:membership_id, :unit_id).group_by(&:first)
      analysts = analysts.map { |membership| [ membership, units.fetch(membership.id, []).map(&:last) ] }
      admins + analysts + consultants(company).map { |membership| [ membership, nil ] }
    end

    def consultants(company)
      return [] if company.direct?

      Membership.active.with_role("consultant").where(organization_type: "Partner", organization_id: company.partner_id)
        .joins(:partner_membership_companies).where(partner_membership_companies: { company_id: company.id }).includes(:user).to_a
    end

    def notify(company, membership, revisions, date)
      path = revisions.one? ? "/employees/#{revisions.first.employment.worker_profile_id}" : "/employees"
      Notifications.notify!("employments.revisions_effective", user: membership.user, membership: membership, company: company,
        subject: company, dedup_key: "employments.revisions_effective/#{company.id}/#{date.iso8601}", path: path,
        count: revisions.size, list: list(revisions))
    end

    def list(revisions)
      names = revisions.first(NAMES_SHOWN).map do |revision|
        "#{revision.employment.worker_profile.display_name} (#{I18n.t("employment_revisions.reasons.#{revision.reason}").downcase})"
      end
      rest = revisions.size - NAMES_SHOWN
      names << I18n.t("notification_types.employments.revisions_effective.more", count: rest) if rest.positive?
      names.to_sentence
    end
  end
end

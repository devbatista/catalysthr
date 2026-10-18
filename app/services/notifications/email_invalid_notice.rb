module Notifications
  # Tells the HR of the person's scope that the person's e-mail bounced (RN-15-083,
  # `contacts.email_invalid`, CA-15-009): in each company where the person has access,
  # the HR administrators and the HR analysts whose units hold the person (D-142); in a
  # partner, its administrators; in an accounting firm, its administrators. The notice
  # names the person and leads to where the contact is corrected, without the address.
  module EmailInvalidNotice
    module_function

    def call(person)
      person.memberships.with_access.includes(:organization).find_each do |membership|
        recipients(membership).each do |recipient|
          next if recipient.user_id == person.id

          Notifications.notify!("contacts.email_invalid", user: recipient.user, membership: recipient, subject: person,
            dedup_key: "contacts.email_invalid/#{person.id}/#{person.email_status_at.to_i}", path: path(membership),
            name: person.name)
        end
      end
    end

    def recipients(membership)
      organization = membership.organization
      case organization
      when Company then ActsAsTenant.with_tenant(organization) { company_hr(membership) }
      when Partner then admins(organization, "partner_admin")
      when AccountingFirm then admins(organization, "firm_admin")
      else []
      end
    end

    def company_hr(membership)
      hr = Membership.active.where(organization: membership.organization).includes(:user).to_a
      admins = hr.select { |candidate| candidate.roles.include?("hr_admin") }
      profiles = WorkerProfile.where(membership: membership)
      analysts = hr.select do |candidate|
        candidate.roles.include?("hr_analyst") && !candidate.roles.include?("hr_admin") &&
          profiles.in_units(MembershipUnit.where(membership: candidate).select(:unit_id)).exists?
      end
      admins + analysts
    end

    def admins(organization, role)
      Membership.active.with_role(role).where(organization: organization).includes(:user).to_a
    end

    # Where the contact is corrected: the person's record, or their access in the team.
    def path(membership)
      case membership.organization
      when Company
        profile = ActsAsTenant.with_tenant(membership.organization) { WorkerProfile.find_by(membership: membership) }
        profile ? "/employees/#{profile.id}" : "/users/#{membership.id}"
      when Partner then "/partner/team/#{membership.id}"
      else "/firm/team/#{membership.id}"
      end
    end
  end
end

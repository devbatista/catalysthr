module Certificates
  # Every day, the notices of the A1 that expires in 30, 15 and 5 days (spec 13, RN-13-022,
  # CA-13-007, P-13-07) to the company's HR administrators, reminding that the same certificate
  # signs the eSocial and the time receipts and AFD (D-319). Each notice goes once: a day the job
  # did not run sends the smallest one passed. Idempotent.
  class ExpirationJob < ApplicationJob
    queue_as :notifications

    def perform
      return unless FeatureFlags.enabled?(FeatureFlags::A1_CERTIFICATE)

      horizon = Time.current + EmployerCertificate::ALERT_DAYS.max.days + 1.day
      company_ids = CrossCompany.scope(EmployerCertificate, Company.all).active.where(valid_to: ..horizon).distinct.pluck(:company_id)
      Company.where(id: company_ids).find_each do |company|
        ActsAsTenant.with_tenant(company) do
          EmployerCertificate.active.where(valid_to: ..horizon).find_each { |certificate| alert(certificate) }
        end
      end
    end

    private

    def alert(certificate)
      days = certificate.days_left
      limit = EmployerCertificate::ALERT_DAYS.select { |each| days <= each }.min
      return if limit.nil? || (certificate.alerted_days && certificate.alerted_days <= limit)

      certificate.with_lock do
        next if certificate.alerted_days && certificate.alerted_days <= limit

        certificate.update!(alerted_days: limit)
        notify(certificate, days)
      end
    end

    def notify(certificate, days)
      company = certificate.company
      Membership.where(organization: company, status: "active").with_role("hr_admin").includes(:user).find_each do |membership|
        Notifications.notify!("certificates.expiring", user: membership.user, membership: membership, subject: certificate,
          path: "/settings/certificate", dedup_key: "certificates.expiring/#{certificate.id}/#{certificate.alerted_days}",
          name: company.name, count: [ days, 0 ].max, date: I18n.l(certificate.valid_to.in_time_zone.to_date))
      end
    end
  end
end

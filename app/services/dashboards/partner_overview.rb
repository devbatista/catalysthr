module Dashboards
  # The partner's consolidated view (spec 17, section 4.5, D-442, D-657, D-660): numbers by
  # company, never people (RN-17-040, CA-17-005), for the partner's administrator with the
  # whole portfolio and the consultant with the assigned companies. Each company is read
  # inside its own tenant. In phase 2: the portfolio and usage, the operational health with its
  # signal, and the adoption; the payroll and eSocial block, the AI and WhatsApp usage and the
  # AI's figures come with their modules (D-657).
  class PartnerOverview
    STOPPED_DAYS = 3
    RED_STOPPED_DAYS = 7
    PORTAL_DAYS = 30
    ACTIVE = %w[active on_leave].freeze

    Portfolio = Data.define(:company, :employees, :modules)
    Health = Data.define(:company, :stopped, :stopped_red, :documents, :late_requests, :overdue) do
      # Red with an admission stopped for more than 7 days; yellow with anything late; green
      # without delays (RN-17-042, D-660).
      def signal
        if stopped_red.positive? then :red
        elsif stopped.positive? || late_requests.positive? || overdue.positive? then :yellow
        else :green
        end
      end
    end
    Adoption = Data.define(:company, :people, :portal, :app_or_push) do
      def portal_percent = percent(portal)
      def app_or_push_percent = percent(app_or_push)

      private

      def percent(count) = people.zero? ? nil : (count * 100.0 / people).round
    end

    attr_reader :partner, :companies

    def initialize(partner, companies)
      @partner = partner
      @companies = companies.to_a
    end

    # Carteira e consumo: the employees active or on leave and the modules turned on, of the
    # ones the contract has (RN-19-012).
    def portfolio
      contracted = partner.contracted_modules if FeatureFlags.enabled?(FeatureFlags::BILLING)
      each_company do |company|
        modules = company.module_settings.select(&:enabled).map(&:module)
        modules &= contracted if contracted
        Portfolio.new(company, active_people.count, modules)
      end
    end

    # The contract's employees in the month against the band (D-480), for the administrator.
    def contract
      subscription = partner.billing_account&.subscription
      return unless subscription

      peak = UsagePeriod.totals.where(billing_account: partner.billing_account, period: UsagePeriod.period_of(Date.current)).maximum(:peak_employees)
      { subscription: subscription, peak: peak, band: subscription.employee_band }
    end

    # Saúde operacional (RN-17-041, RN-17-042, D-660).
    def health
      each_company do |company|
        today = Time.find_zone(company.headquarters&.time_zone || HrPanel::DEFAULT_TIME_ZONE).today
        versions = DocumentVersion.where(status: DocumentVersion::REVIEWABLE, document_id: Document.kept.select(:id)).count
        unanswered = DocumentRequestTarget.pending.where(document_id: Document.kept.select(:id))
        Health.new(company, stopped_admissions(STOPPED_DAYS).count, stopped_admissions(RED_STOPPED_DAYS).count,
          versions + unanswered.count, unanswered.joins(:request).where(document_requests: { due_on: ...today }).count,
          HrPanel.overdue(ProcessItem.all).count)
      end
    end

    # Adoção (RN-17-041, D-657): of the people active or on leave, who used the portal in the
    # last 30 days, and who opened it as the installed app or has the push on.
    def adoption
      each_company do |company|
        user_ids = active_people.joins(:membership).distinct.pluck("memberships.user_id")
        portal = UserSession.where(user_id: user_ids, last_seen_at: PORTAL_DAYS.days.ago..).distinct.count(:user_id)
        app_or_push = User.where(id: user_ids).where.not(app_opened_at: nil)
          .or(User.where(id: PushSubscription.where(user_id: user_ids).select(:user_id))).count
        Adoption.new(company, user_ids.size, portal, app_or_push)
      end
    end

    private

    def each_company(&block)
      companies.map { |company| ActsAsTenant.with_tenant(company) { block.call(company) } }
    end

    def active_people
      WorkerProfile.where(id: Employment.where(status: ACTIVE).select(:worker_profile_id))
    end

    # Open admissions without any event of their process for more than the days, waiting for
    # the employee included (D-657).
    def stopped_admissions(days)
      Admission.in_status("open").where(<<~SQL.squish, days.days.ago)
        COALESCE((SELECT MAX(process_events.created_at) FROM process_events
          WHERE process_events.process_instance_id = process_instances.id), process_instances.created_at) < ?
      SQL
    end
  end
end

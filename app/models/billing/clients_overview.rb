module Billing
  # The Clients block of the CatalystHR team's panel (RN-19-090, RN-19-091, D-610, D-626):
  # each contract not closed with its plan, its employees on the last recorded day, the
  # month's usage against the band and the quotas, the last sign-in and the cancellation
  # risk. Adoption (spec 17) is not in phase 1.
  #
  # Accesses are the sign-ins already recorded as access events (D-626): the people with a
  # sign-in on each day at the contract's brand, without the CatalystHR team. The risk is
  # high with at least two signals:
  # - accesses: the last 30 days have 30% fewer than the 30 before;
  # - late payment: an overdue invoice;
  # - module cancelled: a module removed, or its removal scheduled, in the last 30 days and
  #   not undone;
  # - administrator away: no sign-in in 14 days by the direct company's HR administrators
  #   or the partner's administrators, for a contract started at least 14 days ago.
  class ClientsOverview
    ACCESS_WINDOW = 30
    ACCESS_DROP_PERCENT = 30
    MODULE_WINDOW = 30
    ADMIN_AWAY_DAYS = 14
    HIGH_RISK_SIGNALS = 2
    SIGNALS = %i[accesses late_payment module_cancelled admin_away].freeze

    Row = Data.define(:account, :subscription, :employees, :usage, :band, :quotas, :last_sign_in_at, :signals) do
      def high_risk?
        signals.size >= HIGH_RISK_SIGNALS
      end
    end

    attr_reader :today

    def initialize(today = Date.current)
      @today = today
    end

    def rows
      @rows ||= begin
        subscriptions = Subscription.where.not(status: "closed")
          .includes(:pre_activation_price, { plan_version: :plan }, billing_account: { owner: :brand }).to_a
        accounts = subscriptions.map(&:billing_account)
        @brand_accounts = accounts.to_h { |account| [ account.brand&.id, account.id ] }.except(nil)
        employees = DailyUsage.latest_totals(accounts.map(&:id))
        usages = UsagePeriod.totals.where(billing_account_id: accounts.map(&:id), period: UsagePeriod.period_of(today)).index_by(&:billing_account_id)
        late = Invoice.overdue.where(billing_account_id: accounts.map(&:id)).distinct.pluck(:billing_account_id).to_set
        cancelled = module_cancelled_subscriptions
        last_sign_ins = last_sign_ins_by_account
        drops = access_drops
        away = admins_away(accounts)

        subscriptions.map do |subscription|
          account = subscription.billing_account
          usage = usages[account.id]
          signals = {
            accesses: drops.include?(account.id),
            late_payment: late.include?(account.id),
            module_cancelled: cancelled.include?(subscription.id),
            admin_away: away.include?(account.id)
          }.select { |_, on| on }.keys
          Row.new(account: account, subscription: subscription, employees: employees.fetch(account.id, 0), usage: usage,
            band: subscription.employee_band, quotas: quotas(subscription, usage), last_sign_in_at: last_sign_ins[account.id],
            signals: signals)
        end.sort_by { |row| [ row.high_risk? ? 0 : 1, row.account.name.downcase ] }
      end
    end

    private

    def quotas(subscription, usage)
      subscription.monthly_quotas(usage&.peak_employees)
    end

    def sign_ins
      AccessEvent.where(kind: "auth", action: "sign_in").where("access_events.metadata->>'brand_id' IN (?)", @brand_accounts.keys.presence || [ "" ])
        .where.not(user_id: User.where.not(platform_role: nil).select(:id))
    end

    def last_sign_ins_by_account
      sign_ins.group(Arel.sql("access_events.metadata->>'brand_id'")).maximum(:created_at)
        .transform_keys { |brand_id| @brand_accounts.fetch(brand_id) }
    end

    # People with a sign-in on each day, summed over each window of 30 days.
    def access_drops
      recent_start = (today - ACCESS_WINDOW + 1).beginning_of_day
      previous_start = recent_start - ACCESS_WINDOW.days
      recent = AccessEvent.sanitize_sql_array([ "access_events.created_at >= ?", recent_start ])
      person_day = AccessEvent.sanitize_sql_array(
        [ "(access_events.user_id, DATE(access_events.created_at AT TIME ZONE 'UTC' AT TIME ZONE ?))", Time.zone.tzinfo.identifier ]
      )
      counts = sign_ins.where(created_at: previous_start..today.end_of_day)
        .group(Arel.sql("access_events.metadata->>'brand_id'"), Arel.sql(recent))
        .distinct.count(Arel.sql(person_day))
      @brand_accounts.filter_map do |brand_id, account_id|
        previous = counts.fetch([ brand_id, false ], 0)
        recent = counts.fetch([ brand_id, true ], 0)
        account_id if previous.positive? && (previous - recent) * 100 >= previous * ACCESS_DROP_PERCENT
      end.to_set
    end

    # From the trail: a module item destroyed, or given an end, in the window, unless the
    # end was undone since.
    def module_cancelled_subscriptions
      versions = PaperTrail::Version.where(item_type: "SubscriptionItem", created_at: (today - MODULE_WINDOW).beginning_of_day..)
        .where("versions.object->>'kind' = 'module'")
        .where("versions.event = 'destroy' OR (versions.event = 'update' AND versions.object_changes->'ends_on'->>1 IS NOT NULL)")
        .pluck(Arel.sql("versions.object->>'subscription_id'"), :item_id, :event)
      ended = SubscriptionItem.where(id: versions.select { |*, event| event == "update" }.map(&:second)).where.not(ends_on: nil).pluck(:id).to_set
      versions.filter_map { |subscription_id, item_id, event| subscription_id if event == "destroy" || ended.include?(item_id) }.to_set
    end

    def admins_away(accounts)
      started = accounts.select { |account| account.subscription.started_on <= today - ADMIN_AWAY_DAYS }
      return Set.new if started.empty?

      partners, directs = started.partition(&:partner?)
      by_owner = started.index_by { |account| [ account.owner_type, account.owner_id ] }
      admins = Membership.with_access.with_role("partner_admin").where(organization_type: "Partner", organization_id: partners.map(&:owner_id))
        .or(Membership.with_access.with_role("hr_admin").where(organization_type: "Company", organization_id: directs.map(&:owner_id)))
        .pluck(:organization_type, :organization_id, :user_id)
        .group_by { |type, id, _| by_owner.fetch([ type, id ]).id }.transform_values { |rows| rows.map(&:last) }
      admins = started.to_h { |account| [ account.id, admins.fetch(account.id, []) ] }
      present = sign_ins.where(user_id: admins.values.flatten, created_at: (today - ADMIN_AWAY_DAYS + 1).beginning_of_day..)
        .distinct.pluck(Arel.sql("access_events.metadata->>'brand_id'"), :user_id)
        .map { |brand_id, user_id| [ @brand_accounts.fetch(brand_id), user_id ] }.to_set
      admins.filter_map { |account_id, user_ids| account_id if user_ids.none? { |user_id| present.include?([ account_id, user_id ]) } }.to_set
    end
  end
end

module Billing
  # The cancellation asked by the client (RN-19-062, RN-19-063, D-489, D-625): the financial
  # responsible asks, with the password and a reason, and it takes effect at the end of the
  # paid cycle, with no fee. The invoice of the next cycle already issued and not paid is
  # voided; one already paid moves the end to the end of its cycle. Until that day, the
  # client or the team undoes it. On the next day the contract goes into closing (D-222),
  # read only (D-624). A partner's companies are told 30 days before the end, or at the
  # request when less is left.
  module Cancellation
    REASONS = %w[price missing_feature other_system usability business_closed other].freeze
    CANCELLABLE = %w[active past_due].freeze
    PORTFOLIO_NOTICE_DAYS = 30
    # The statuses a scheduled cancellation still waits in; read only and past due keep it.
    WAITING = %w[cancel_scheduled past_due read_only].freeze

    module_function

    def scheduled?(subscription)
      subscription&.cancel_on.present? && !subscription.closing? && !subscription.closed?
    end

    # The last day of the paid cycle and the invoices of later cycles to void.
    def effective_on(account, today)
      invoices = account.invoices.where.not(status: "void").where(period_end: today..).order(:period_start).to_a
      cancel_on = invoices.find { |invoice| invoice.period_start <= today }&.period_end || today
      later = invoices.select { |invoice| invoice.period_start > today }
      later.select(&:paid?).each { |invoice| cancel_on = [ cancel_on, invoice.period_end ].max }
      [ cancel_on, later.reject(&:paid?) ]
    end

    # :scheduled, or why not: :not_cancellable, :reason or :reason_text.
    def schedule(subscription, by:, reason:, text:, today: Date.current)
      return :reason unless reason.in?(REASONS)
      return :reason_text if reason == "other" && text.blank?

      result = subscription.with_lock do
        next :not_cancellable unless subscription.status.in?(CANCELLABLE) && subscription.cancel_on.nil?

        account = subscription.billing_account
        cancel_on, to_void = effective_on(account, today)
        to_void.each { |invoice| invoice.update!(status: "void", void_reason: "contract_cancelled", voided_at: Time.current) }
        subscription.update!(status: subscription.active? ? "cancel_scheduled" : subscription.status, cancel_on: cancel_on,
          cancel_requested_at: Time.current, cancel_requested_by: by, cancel_reason: reason, cancel_reason_text: text.to_s.strip.presence)
        :scheduled
      end
      return result unless result == :scheduled

      notify(subscription)
      notify_portfolio(subscription, today)
      result
    end

    # :undone, or :not_scheduled. The team gives the reason; the client does not.
    def undo(subscription, by:, reason: nil, today: Date.current)
      subscription.with_lock do
        next :not_scheduled unless scheduled?(subscription) && subscription.cancel_on >= today

        subscription.update!(status: subscription.cancel_scheduled? ? "active" : subscription.status, cancel_on: nil,
          cancel_requested_at: nil, cancel_requested_by: nil, cancel_reason: nil, cancel_reason_text: nil,
          cancel_portfolio_notified_on: nil, cancel_undone_at: Time.current, cancel_undone_by: by, cancel_undone_reason: reason.presence)
        :undone
      end
    end

    # Every day: the cancellations whose day passed go into closing, and the portfolios
    # reach the 30 days' notice.
    def apply_due(today = Date.current)
      Subscription.where(status: WAITING + CANCELLABLE).where.not(cancel_on: nil).find_each do |subscription|
        subscription.with_lock do
          next unless scheduled?(subscription)

          if subscription.cancel_on < today
            subscription.update!(status: "closing", closing_on: today)
          end
        end
        notify_portfolio(subscription, today) if scheduled?(subscription.reload)
      end
    end

    # The responsible: when it takes effect and how to undo (`billing.cancel_scheduled`).
    def notify(subscription)
      account = subscription.billing_account
      account.notice_recipients.each do |membership|
        Notifications.notify!("billing.cancel_scheduled", user: membership.user, membership: membership, subject: subscription,
          path: account.partner? ? "/partner/contract/cancellation" : "/contract/cancellation",
          dedup_key: "billing.cancel_scheduled/#{subscription.id}/#{subscription.cancel_requested_at.to_i}",
          name: account.name, date: I18n.l(subscription.cancel_on))
      end
    end

    # The HR administrator of each company of the portfolio, once, 30 days before the end
    # or at the request when less is left (RN-19-063, `billing.partner_cancelled`).
    def notify_portfolio(subscription, today)
      account = subscription.billing_account
      return unless account.partner? && subscription.cancel_portfolio_notified_on.nil?
      return if subscription.cancel_on - PORTFOLIO_NOTICE_DAYS > today

      Membership.active.with_role("hr_admin").where(organization_type: "Company", organization_id: account.owner.companies.select(:id))
        .includes(:user, :organization).find_each do |membership|
        Notifications.notify!("billing.partner_cancelled", user: membership.user, membership: membership, path: "/",
          dedup_key: "billing.partner_cancelled/#{membership.organization_id}/#{subscription.cancel_on.iso8601}",
          partner: account.name, company_name: membership.organization.name, date: I18n.l(subscription.cancel_on))
      end
      subscription.update!(cancel_portfolio_notified_on: today)
    end
  end
end

module Billing
  # The dunning schedule (RN-19-050, RN-19-053, D-116, D-493, D-495, D-624), counted from the
  # due date of the contract's oldest invoice not paid:
  # - day 1: the invoices past due become `overdue`, the contract `past_due`, and the
  #   responsible is told; again on days 5 and 10, the last one saying the read only is near;
  # - day 15: `read_only`, for the contract and all its companies; the HR administrator of
  #   each company of a partner's portfolio is told too, without amounts;
  # - day 25: the notice that the contract goes into closing; day 30: `closing`.
  # The status follows the oldest invoice still not paid, so a payment brings it back
  # (RN-19-053), except from closing, which only the superadmin reactivates. Each invoice
  # keeps the last step it went through: running again, or after a day the job missed,
  # repeats no notice.
  module Dunning
    STEPS = { 1 => "first", 5 => "reminder", 10 => "read_only_soon", 15 => "read_only", 25 => "soon", 30 => "closing" }.freeze
    READ_ONLY_DAY = 15
    CLOSING_DAY = 30
    # The statuses the schedule moves; closing waits for the superadmin.
    DUNNED = %w[active past_due read_only].freeze
    # How long the superadmin may reactivate a contract in closing (RN-19-053, P-19-18).
    REACTIVATION_DAYS = 90

    module_function

    def run(today = Date.current)
      Subscription.where(status: DUNNED).includes(:billing_account).find_each { |subscription| apply(subscription, today) }
    end

    def apply(subscription, today)
      subscription.with_lock do
        next unless subscription.status.in?(DUNNED)

        account = subscription.billing_account
        late = account.invoices.where(status: %w[open overdue], due_on: ...today).where("total_cents > 0").order(:due_on, :number).to_a
        late.each { |invoice| invoice.update!(status: "overdue") if invoice.open? }
        oldest = late.first
        status = status_for(oldest, today)
        subscription.update!(status: status, closing_on: (today if status == "closing")) if status != subscription.status
        notify(account, oldest, today) if oldest
      end
    end

    def status_for(oldest, today)
      return "active" if oldest.nil?

      days = (today - oldest.due_on).to_i
      if days >= CLOSING_DAY then "closing"
      elsif days >= READ_ONLY_DAY then "read_only"
      else "past_due"
      end
    end

    # The latest step reached and not yet told.
    def notify(account, invoice, today)
      step = STEPS.keys.select { |day| day <= (today - invoice.due_on).to_i }.max
      return if step.nil? || step <= invoice.dunning_stage

      invoice.update!(dunning_stage: step)
      code = step >= 25 ? "billing.contract_closing" : "billing.overdue"
      path = account.partner? ? "/partner/invoices/#{invoice.id}" : "/invoices/#{invoice.id}"
      account.notice_recipients.each do |membership|
        Notifications.notify!(code, user: membership.user, membership: membership, subject: invoice, path: path, variant: STEPS[step],
          dedup_key: "#{code}/#{invoice.id}/#{step}", name: account.name, number: invoice.display_number,
          total: "R$ #{MoneyCents.format(invoice.total_cents)}", due: I18n.l(invoice.due_on),
          read_only_on: I18n.l(invoice.due_on + READ_ONLY_DAY), closing_on: I18n.l(invoice.due_on + CLOSING_DAY))
      end
      notify_portfolio(account) if step == READ_ONLY_DAY && account.partner?
    end

    # :reactivated, or why not: :not_closing, :too_late, :past_due or :without_reason.
    def reactivate(subscription, by:, reason:, today: Date.current)
      return :not_closing if subscription.nil?

      subscription.with_lock do
        next :not_closing unless subscription.closing?
        next :too_late if subscription.closing_on.nil? || subscription.closing_on + REACTIVATION_DAYS < today
        next :without_reason if reason.blank?

        account = subscription.billing_account
        next :past_due if account.invoices.where(status: %w[open overdue], due_on: ...today).where("total_cents > 0").exists?

        subscription.update!(status: "active", closing_on: nil, reactivated_at: Time.current, reactivated_by: by,
          reactivation_reason: reason.strip)
        :reactivated
      end
    end

    # The partner's companies learn of the read only, never of the amounts (RN-19-052, D-495).
    def notify_portfolio(account)
      Membership.active.with_role("hr_admin").where(organization_type: "Company", organization_id: account.owner.companies.select(:id))
        .includes(:user, :organization).find_each do |membership|
        Notifications.notify!("billing.partner_read_only", user: membership.user, membership: membership, path: "/",
          dedup_key: "billing.partner_read_only/#{membership.organization_id}/#{Date.current.iso8601}",
          partner: account.name, company_name: membership.organization.name)
      end
    end
  end
end

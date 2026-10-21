module Billing
  # Every morning, the free trial (RN-19-030 to RN-19-034, D-613, D-616): 3 days and
  # 1 day before the end, tells the contract's responsible that the trial is ending
  # (`billing.trial_ending`); on the end date, without a contract, the subscription goes
  # to trial_expired and the responsible is told (`billing.trial_expired`). The read-only
  # mode comes with block 19f, and the button to contract with 19e. Runs again without
  # repeating: a status changes once, and the same notice for the same day is not repeated
  # (RN-15-085). A day the job did not run still ends the trial on the next run. Does
  # nothing while billing is off (D-610).
  class TrialJob < ApplicationJob
    queue_as :default

    NOTICE_DAYS = [ 3, 1 ].freeze

    def perform(date = Date.current)
      return unless FeatureFlags.enabled?(FeatureFlags::BILLING)

      Subscription.trialing.where(trial_ends_on: ..date).includes(billing_account: :owner).find_each do |subscription|
        expire(subscription, date)
      end
      ending = NOTICE_DAYS.map { |days| date + days }
      Subscription.trialing.where(trial_ends_on: ending).includes(billing_account: :owner).find_each do |subscription|
        notify(subscription, "billing.trial_ending", date, count: (subscription.trial_ends_on - date).to_i)
      end
    end

    private

    def expire(subscription, date)
      subscription.with_lock do
        next unless subscription.trialing?

        subscription.update!(status: "trial_expired")
        notify(subscription, "billing.trial_expired", date)
      end
    end

    def notify(subscription, code, date, **params)
      account = subscription.billing_account
      account.notice_recipients.each do |membership|
        Notifications.notify!(code, user: membership.user, membership: membership, subject: subscription,
          dedup_key: "#{code}/#{subscription.id}/#{date.iso8601}", path: account.partner? ? "/partner/contract/new" : "/contract/new",
          name: account.name, date: I18n.l(subscription.trial_ends_on), **params)
      end
    end
  end
end

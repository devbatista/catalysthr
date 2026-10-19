require "rails_helper"

# Spec 19, RN-19-001, RN-19-002 and RN-19-035 (D-612, D-613).
RSpec.describe Subscription do
  let(:finance) { create(:user, platform_role: "finance") }

  def subscription_for(owner, plan_kind:, **attributes)
    account = BillingAccount.create!(owner: owner, cycle_day: 10)
    plan = plan_kind == "partner" ? create(:plan) : create(:plan, :direct)
    described_class.new(billing_account: account, plan_version: create(:plan_version, plan: plan), created_by: finance,
      started_on: Date.current, status: "active", **attributes)
  end

  it "bills a partner's company through the partner, never with a contract of its own (RN-19-001)" do
    company = create(:company, partner: create(:partner))

    account = BillingAccount.new(owner: company, cycle_day: 10)

    expect(account).not_to be_valid
    expect(account.errors[:owner]).to be_present
  end

  it "takes only a plan of the client's kind" do
    subscription = subscription_for(create(:company), plan_kind: "partner", activated_on: Date.current)

    expect(subscription).not_to be_valid
    expect(subscription.errors[:plan_version]).to include("precisa ser do mesmo tipo do cliente")
  end

  it "keeps a partner under contract in pre-activation until the first active employee (D-612)" do
    subscription = subscription_for(create(:partner), plan_kind: "partner")

    expect(subscription).not_to be_valid
    expect(subscription.errors[:pre_activation_price]).to be_present

    subscription.pre_activation_price = create(:pre_activation_price)
    expect(subscription).to be_valid
    expect(subscription).to be_pre_activation

    subscription.activated_on = Date.current
    expect(subscription).not_to be_pre_activation
  end

  it "has no pre-activation in the trial nor for a direct company" do
    expect(subscription_for(create(:partner), plan_kind: "partner", status: "trialing", trial_ends_on: 14.days.from_now)).not_to be_pre_activation
    expect(subscription_for(create(:company), plan_kind: "direct", activated_on: Date.current)).not_to be_pre_activation
  end
end

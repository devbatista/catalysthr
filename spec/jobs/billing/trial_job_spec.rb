require "rails_helper"

# Spec 19, RN-19-032 and RN-19-034 (D-613, D-616): the trial's notices 3 days and 1 day
# before the end, and the trial_expired status on the end date, to the responsible.
RSpec.describe Billing::TrialJob do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:responsible) { create(:membership, organization: company, roles: %w[hr_admin], status: "active") }
  let(:today) { Date.new(2026, 10, 20) }
  let(:subscription) do
    contract_for(company, status: "trialing").tap do |subscription|
      subscription.update!(trial_ends_on: Date.new(2026, 10, 23))
      subscription.billing_account.update!(responsible_user: responsible.user)
    end
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 20, 6)) { example.run } }

  def notices(code)
    Notification.where(notification_type: code)
  end

  it "tells the responsible 3 days and 1 day before the end, once a day, with no button to contract (RN-19-032)" do
    subscription

    perform_enqueued_jobs { 2.times { described_class.perform_now(today) } }
    notice = notices("billing.trial_ending").sole
    expect(notice).to have_attributes(recipient_user: responsible.user, recipient_membership: responsible, company: company,
      path: "/", mandatory: true, title: "O teste grátis de Metalúrgica Serra Azul termina em 3 dias")
    expect(notice.body).to include("23/10/2026", "fale com a equipe da CatalystHR")
    expect(notice.deliveries.sole.channel).to eq("email")

    described_class.perform_now(today + 1)
    expect(notices("billing.trial_ending").count).to eq(1)

    described_class.perform_now(today + 2)
    expect(notices("billing.trial_ending").pluck(:title)).to contain_exactly(
      "O teste grátis de Metalúrgica Serra Azul termina em 3 dias", "O teste grátis de Metalúrgica Serra Azul termina amanhã")
    expect(subscription.reload).to be_trialing
  end

  it "ends the trial on the end date, once, and tells the responsible (RN-19-034)" do
    subscription

    2.times { described_class.perform_now(Date.new(2026, 10, 23)) }

    expect(subscription.reload).to be_trial_expired
    expect(notices("billing.trial_expired").sole).to have_attributes(recipient_membership: responsible,
      title: "O teste grátis de Metalúrgica Serra Azul terminou")
    expect(notices("billing.trial_ending")).to be_empty
  end

  it "ends a trial whose end date passed on a day the job did not run" do
    subscription

    described_class.perform_now(Date.new(2026, 10, 25))

    expect(subscription.reload).to be_trial_expired
  end

  it "leaves a contract alone" do
    contract_for(create(:company), status: "active")

    described_class.perform_now(Date.new(2026, 10, 25))

    expect(Subscription.sole).to be_active
    expect(Notification.count).to eq(0)
  end

  it "tells the partner's administrators when the responsible no longer has access" do
    partner = create(:partner, name: "Aurora Gestão de Pessoas")
    create(:brand, owner: partner).subdomains.create!(slug: "aurora")
    gone = create(:membership, organization: partner, roles: %w[partner_admin], status: "revoked")
    admin = create(:membership, organization: partner, roles: %w[partner_admin], status: "active")
    trial = contract_for(partner, status: "trialing")
    trial.update!(trial_ends_on: today + 1)
    trial.billing_account.update!(responsible_user: gone.user)

    described_class.perform_now(today)

    expect(notices("billing.trial_ending").sole).to have_attributes(recipient_membership: admin, path: "/partner",
      title: "O teste grátis de Aurora Gestão de Pessoas termina amanhã")
  end
end

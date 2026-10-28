require "rails_helper"

# Spec 19, RN-19-109 and RN-19-108 (P-19-34, D-633): Asaas out of the air is tried again 1, 5
# and 15 minutes later; the tries spent, the note shows the error.
RSpec.describe Billing::IssueServiceInvoiceJob do
  include ActiveJob::TestHelper

  let(:subscription) { contract_for(create(:partner)) }
  let(:account) { subscription.billing_account }
  let(:lookup) { stub_request(:get, "#{AsaasStub::BASE_URL}/customers?externalReference=#{account.id}").to_timeout }
  let(:note) do
    perform_enqueued_jobs(only: []) do
      account.invoices.sole.update!(status: "paid", paid_at: Time.current)
      account.invoices.sole.service_invoice
    end
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 29, 10)) { example.run } }

  before do
    Flipper.enable(FeatureFlags::NFSE)
    configure_asaas
    FiscalSetting.current.tap { |setting| setting.assign_attributes(service_code: "010501", updated_by: create(:user, platform_role: "finance")) }.save!
    Billing::Invoicing.issue_due(subscription, Date.current, lead: 0)
    lookup
    allow(Rails.error).to receive(:report)
  end

  it "tries again 1 minute after the first failure" do
    expect { described_class.perform_now(note) }.to have_enqueued_job(described_class).with(note).at(1.minute.from_now)
    expect(note.reload).to be_pending
  end

  it "shows the error after the fourth try" do
    perform_enqueued_jobs { described_class.perform_later(note) }

    expect(lookup).to have_been_requested.times(4)
    expect(note.reload).to have_attributes(status: "error", error_message: "O Asaas ficou fora do ar nas 4 tentativas de envio.")
  end
end

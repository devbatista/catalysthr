require "rails_helper"

# Spec 06, P-06-20, and spec 11, P-11-06 (D-638): the next year's national holidays from
# BrasilAPI, waiting for the team's review.
RSpec.describe Holidays::ImportNationalJob do
  let(:brasil_api) { "https://brasilapi.com.br/api/feriados/v1/2027" }
  let!(:superadmin) { create(:user, platform_role: "superadmin", cpf: "52998224725") }
  let!(:support) { create(:user, platform_role: "support", cpf: "11144477735") }

  before { create(:user, platform_role: "finance", cpf: "98765432100") }

  around { |example| travel_to(Time.zone.local(2026, 11, 1, 4)) { example.run } }

  it "brings the next year and tells the superadmins and the support once" do
    stub_request(:get, brasil_api).to_return(body: [ { date: "2027-11-15", name: "Proclamação da República", type: "national" } ].to_json)

    2.times { described_class.perform_now }

    expect(Holiday.sole).to have_attributes(date: Date.new(2027, 11, 15), status: "pending")
    expect(Notification.pluck(:recipient_user_id)).to contain_exactly(superadmin.id, support.id)
    expect(Notification.first).to have_attributes(notification_type: "platform.holidays_review", area: "admin",
      title: "Feriados nacionais de 2027 aguardando revisão")
  end

  it "raises when BrasilAPI fails, so Sidekiq tries again and Sentry sees it" do
    stub_request(:get, brasil_api).to_return(status: 503)

    expect { described_class.perform_now }.to raise_error(Holidays::BrasilApi::Error)
    expect(Notification.count).to eq(0)
  end
end

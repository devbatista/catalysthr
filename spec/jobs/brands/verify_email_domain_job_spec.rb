require "rails_helper"

# Spec 01, RN-01-040 and D-596: the hourly check of the e-mail domains in SES.
RSpec.describe Brands::VerifyEmailDomainJob do
  include ActiveJob::TestHelper

  let(:partner) { create(:partner) }
  let(:support) { create(:user, platform_role: "support", email: "sofia@catalysthr.com.br") }
  let!(:brand) do
    create(:brand, owner: partner, commercial_name: "Aurora RH", email_domain: "aurora.com.br",
      email_domain_status: "pending", email_domain_registered_by: support)
  end
  let!(:partner_admin) { create(:user, email: "ana@aurora.com.br") }

  before do
    brand.subdomains.create!(slug: "aurora")
    create(:membership, user: partner_admin, organization: partner, roles: %w[partner_admin])
    create(:membership, user: create(:user, email: "caio@aurora.com.br"), organization: partner, roles: %w[consultant])
  end

  it "marks the domain verified when the DKIM and the MAIL FROM are confirmed, and tells who registered it and the partner's admins" do
    stub_ses(get_email_identity: ses_identity(dkim: "SUCCESS", mail_from: "SUCCESS"))

    perform_enqueued_jobs { described_class.perform_now }

    expect(brand.reload).to have_attributes(email_domain_status: "verified")
    expect(brand.email_domain_checked_at).to be_present
    mails = ActionMailer::Base.deliveries
    expect(mails.flat_map(&:to)).to contain_exactly("sofia@catalysthr.com.br", "ana@aurora.com.br")
    expect(mails.map(&:subject).uniq).to eq([ "Domínio de e-mail verificado: aurora.com.br" ])
    expect(mails.first[:from].to_s).to eq("Aurora RH <no-reply@aurora.com.br>")
  end

  it "stays pending while either is not confirmed, without notices" do
    stub_ses(get_email_identity: ses_identity(dkim: "SUCCESS", mail_from: "PENDING"))

    perform_enqueued_jobs { described_class.perform_now }

    expect(brand.reload.email_domain_status).to eq("pending")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "marks a failure and tells it once, even when the job runs again" do
    stub_ses(get_email_identity: ses_identity(dkim: "FAILED", mail_from: "PENDING"))

    perform_enqueued_jobs { 2.times { described_class.perform_now } }

    expect(brand.reload.email_domain_status).to eq("failed")
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(ActionMailer::Base.deliveries.first.subject).to eq("A verificação do domínio aurora.com.br falhou")
    expect(ActionMailer::Base.deliveries.first[:from].to_s).to eq("Aurora RH <no-reply@catalysthr.com.br>")
  end

  it "keeps asking about a failed domain, in case SES finds the records later" do
    brand.update!(email_domain_status: "failed")
    stub_ses(get_email_identity: ses_identity(dkim: "SUCCESS", mail_from: "SUCCESS"))

    described_class.perform_now

    expect(brand.reload.email_domain_status).to eq("verified")
  end

  it "does not ask about verified domains, and goes on when SES is down" do
    create(:brand, owner: create(:partner), email_domain: "feito.com.br", email_domain_status: "verified")
    client = stub_ses(get_email_identity: "ServiceUnavailable")

    expect { described_class.perform_now }.not_to raise_error

    expect(client.api_requests.map { |request| request[:params][:email_identity] }).to eq([ "aurora.com.br" ])
    expect(brand.reload.email_domain_status).to eq("pending")
  end
end

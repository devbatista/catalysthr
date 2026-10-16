require "rails_helper"

# Spec 01, RN-01-040 and D-596: the brand's e-mail domain in SES.
RSpec.describe "Brand e-mail domain" do
  let(:user) { create(:user, platform_role: "support") }
  let(:brand) { create(:brand, owner: create(:partner)) }

  describe Brands::RegisterEmailDomain do
    it "creates the identity with the MAIL FROM and keeps the DNS records to show" do
      client = stub_ses

      described_class.call(brand: brand, domain: " AuroraGestao.com.br. ", user: user)

      expect(brand.reload).to have_attributes(email_domain: "auroragestao.com.br", email_domain_status: "pending",
        email_domain_registered_by: user)
      expect(brand.email_domain_records).to eq([
        { "type" => "CNAME", "name" => "tok1abc._domainkey.auroragestao.com.br", "value" => "tok1abc.dkim.sa-east-1.amazonses.com" },
        { "type" => "CNAME", "name" => "tok2def._domainkey.auroragestao.com.br", "value" => "tok2def.dkim.sa-east-1.amazonses.com" },
        { "type" => "CNAME", "name" => "tok3ghi._domainkey.auroragestao.com.br", "value" => "tok3ghi.dkim.sa-east-1.amazonses.com" },
        { "type" => "MX", "name" => "bounce.auroragestao.com.br", "value" => "10 feedback-smtp.sa-east-1.amazonses.com" },
        { "type" => "TXT", "name" => "bounce.auroragestao.com.br", "value" => "v=spf1 include:amazonses.com ~all" }
      ])
      create_call, mail_from_call = client.api_requests.map { |request| [ request[:operation_name], request[:params] ] }
      expect(create_call).to eq([ :create_email_identity,
        { email_identity: "auroragestao.com.br", configuration_set_name: "catalysthr-padrao" } ])
      expect(mail_from_call).to eq([ :put_email_identity_mail_from_attributes,
        { email_identity: "auroragestao.com.br", mail_from_domain: "bounce.auroragestao.com.br", behavior_on_mx_failure: "USE_DEFAULT_VALUE" } ])
    end

    it "refuses the platform's domain, its subdomains and another brand's, with the same message" do
      client = stub_ses
      create(:brand, owner: create(:partner), email_domain: "outra.com.br", email_domain_status: "verified")

      %w[catalysthr.com.br rh.catalysthr.com.br outra.com.br].each do |domain|
        result = described_class.call(brand: brand.reload, domain: domain, user: user)
        expect(result.errors[:email_domain]).to eq([ "não pode ser usado. Se o domínio é seu, fale com o suporte" ])
      end
      expect(client.api_requests).to be_empty
      expect(brand.reload.email_domain).to be_nil
    end

    it "refuses what is not a domain" do
      stub_ses

      %w[rh@aurora.com.br https://aurora.com.br aurora].each do |domain|
        expect(described_class.call(brand: brand.reload, domain: domain, user: user).errors[:email_domain]).to be_present
      end
    end

    it "refuses a domain that is already an identity of the account" do
      stub_ses(create_email_identity: "AlreadyExistsException")

      result = described_class.call(brand: brand, domain: "aurora.com.br", user: user)

      expect(result.errors[:email_domain]).to include("não pode ser usado. Se o domínio é seu, fale com o suporte")
      expect(brand.reload.email_domain).to be_nil
    end

    it "keeps nothing when SES is down, and deletes the identity when the MAIL FROM fails" do
      client = stub_ses(put_email_identity_mail_from_attributes: "ServiceUnavailable")

      result = described_class.call(brand: brand, domain: "aurora.com.br", user: user)

      expect(result.errors[:base]).to eq([ "Não foi possível falar com o serviço de e-mail agora. Tente de novo em alguns minutos" ])
      expect(brand.reload.email_domain).to be_nil
      expect(client.api_requests.map { |request| request[:operation_name] }).to include(:delete_email_identity)
    end

    it "asks to remove the current domain before another one" do
      stub_ses
      brand.update!(email_domain: "aurora.com.br", email_domain_status: "pending")

      expect(described_class.call(brand: brand, domain: "outra.com.br", user: user).errors[:email_domain])
        .to eq([ "já está cadastrado. Remova o atual para cadastrar outro" ])
    end

    it "does not call SES in an impersonate simulation (RN-02-085)" do
      client = stub_ses
      Current.simulation = true

      described_class.call(brand: brand, domain: "aurora.com.br", user: user)

      expect(client.api_requests).to be_empty
    end
  end

  describe Brands::RemoveEmailDomain do
    before { brand.update!(email_domain: "aurora.com.br", email_domain_status: "verified", email_domain_registered_by: user) }

    it "deletes the identity and goes back to not configured" do
      client = stub_ses

      expect(described_class.call(brand: brand)).to be(true)

      expect(brand.reload).to have_attributes(email_domain: nil, email_domain_status: nil, email_domain_records: [])
      expect(client.api_requests.map { |request| request[:params] }).to eq([ { email_identity: "aurora.com.br" } ])
    end

    it "also clears a domain whose identity no longer exists" do
      stub_ses(delete_email_identity: "NotFoundException")

      expect(described_class.call(brand: brand)).to be(true)
      expect(brand.reload.email_domain).to be_nil
    end

    it "keeps the domain when SES is down" do
      stub_ses(delete_email_identity: "ServiceUnavailable")

      expect(described_class.call(brand: brand)).to be(false)
      expect(brand.reload.email_domain).to eq("aurora.com.br")
    end
  end
end

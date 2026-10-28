require "rails_helper"

# Spec 19, section 8 and P-19-37 (D-633): our own client of Asaas's API, used only for the
# NFS-e. The key's prefix picks the environment, so a sandbox key never reaches production.
RSpec.describe Billing::Asaas do
  describe ".environment" do
    it "is the sandbox for a sandbox key and production for a production key" do
      configure_asaas(key: "$aact_hmlg_abc")
      expect(described_class.environment).to eq(:sandbox)

      configure_asaas(key: "$aact_prod_abc")
      expect(described_class.environment).to eq(:production)
    end

    it "is nil without a key or with an unknown one, and then nothing is configured" do
      expect(described_class.environment).to be_nil
      configure_asaas(key: "outra-chave")
      expect(described_class).not_to be_configured
    end
  end

  describe "the calls" do
    before { configure_asaas }

    it "sends the key and a User-Agent, and returns the account's fiscal setup" do
      stub = stub_asaas_fiscal_info

      expect(described_class.fiscal_info).to include("useNationalPortal" => true, "nbsCode" => "1.1506.21.00")
      expect(stub.with(headers: { "User-Agent" => "CatalystHR" })).to have_been_requested
    end

    it "talks to production with a production key" do
      configure_asaas(key: "$aact_prod_abc")
      stub = stub_request(:get, "https://api.asaas.com/v3/fiscalInfo/").to_return(status: 200, body: "{}")

      described_class.fiscal_info

      expect(stub).to have_been_requested
    end

    it "takes a missing fiscal setup (404) as none" do
      stub_asaas_fiscal_info({ errors: [] }, status: 404)

      expect(described_class.fiscal_info).to be_nil
    end

    it "raises with Asaas's status, code and description, never the body" do
      stub_asaas(:get, "/fiscalInfo/municipalOptions", status: 400,
        body: { errors: [ { code: "invalid_object", description: "Código NBS inválido." } ] })

      expect { described_class.municipal_options }.to raise_error(described_class::Error, "Asaas answered 400 (invalid_object)") { |error|
        expect(error).to have_attributes(status: 400, code: "invalid_object", description: "Código NBS inválido.")
      }
    end

    it "raises when Asaas is out of the air" do
      stub_request(:get, "#{AsaasStub::BASE_URL}/fiscalInfo/").to_timeout

      expect { described_class.fiscal_info }.to raise_error(described_class::Error, /unavailable/) { |error| expect(error.status).to eq(0) }
    end
  end

  describe ".download" do
    it "fetches a note's file from Asaas's domain, without the key" do
      stub = stub_request(:get, "https://sandbox.asaas.com/nfse/pdf/inv_1").to_return(status: 200, body: "%PDF")

      expect(described_class.download("https://sandbox.asaas.com/nfse/pdf/inv_1")).to eq("%PDF")
      expect(stub.with { |request| !request.headers.key?("Access-Token") }).to have_been_requested
    end

    it "refuses another domain, plain HTTP and a file over the limit" do
      expect { described_class.download("https://evil.example/asaas.com/x") }.to raise_error(described_class::Error, /refused/)
      expect { described_class.download("https://asaas.com.evil.example/x") }.to raise_error(described_class::Error, /refused/)
      expect { described_class.download("http://sandbox.asaas.com/x") }.to raise_error(described_class::Error, /refused/)

      stub_request(:get, "https://www.asaas.com/big").to_return(status: 200, body: "x" * (described_class::FILE_LIMIT + 1))
      expect { described_class.download("https://www.asaas.com/big") }.to raise_error(described_class::Error, /too large/)
    end
  end

  it "refuses to call without a key" do
    expect { described_class.fiscal_info }.to raise_error(described_class::Error, "Asaas API key is not configured")
  end
end

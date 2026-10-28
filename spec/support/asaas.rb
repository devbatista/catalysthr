# Asaas's API answered by WebMock (D-633): no request leaves the test. The bodies are the
# sandbox's own answers, with the e-mail replaced (spec/fixtures/files/asaas), except the
# authorized note, built from the documented fields: no note was issued in the sandbox.
module AsaasStub
  KEY = "$aact_hmlg_000TesteDoSandbox".freeze
  BASE_URL = "https://api-sandbox.asaas.com/v3".freeze

  def configure_asaas(key: KEY)
    Rails.configuration.x.asaas_api_key = key
  end

  def asaas_fixture(name)
    JSON.parse(file_fixture("asaas/#{name}.json").read)
  end

  def stub_asaas(method, path, body: {}, status: 200)
    stub_request(method, "#{BASE_URL}#{path}").with(headers: { "access_token" => KEY })
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_asaas_fiscal_info(body = asaas_fixture("fiscal_info"), status: 200)
    stub_asaas(:get, "/fiscalInfo/", body: body, status: status)
  end

  # A note as GET /invoices/{id} answers, with the id and status given.
  def asaas_invoice(id:, status: "AUTHORIZED", **attributes)
    asaas_fixture("invoice").merge("id" => id, "status" => status).merge(attributes.transform_keys(&:to_s))
  end

  def stub_asaas_invoice(note)
    stub_asaas(:get, "/invoices/#{note["id"]}", body: note)
  end

  # The note's PDF and XML at the addresses of the fixture.
  def stub_asaas_files(id = "inv_000000000001")
    stub_request(:get, "https://sandbox.asaas.com/nfse/pdf/#{id}").to_return(status: 200, body: "%PDF-1.7 nota")
    stub_request(:get, "https://sandbox.asaas.com/nfse/xml/#{id}").to_return(status: 200, body: "<NFSe/>")
  end
end

RSpec.configure do |config|
  config.include AsaasStub
  config.after do
    Rails.configuration.x.asaas_api_key = nil
    Rails.configuration.x.asaas_webhook_token = nil
  end
end

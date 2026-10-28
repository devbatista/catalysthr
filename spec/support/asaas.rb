# Asaas's API answered by WebMock (D-633): no request leaves the test. The bodies are the
# sandbox's own answers, with the e-mail replaced (spec/fixtures/files/asaas).
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
end

RSpec.configure do |config|
  config.include AsaasStub
  config.after { Rails.configuration.x.asaas_api_key = nil }
end

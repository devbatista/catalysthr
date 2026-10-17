require "rails_helper"

# Spec 04, section 8: the address by CEP (D-215, P-04-28) and the suggested position
# (D-216). Recorded answers only; no test reaches the services.
RSpec.describe "Address services" do
  describe Addresses::PostalCodeLookup do
    let(:via_cep) { "https://viacep.com.br/ws/01310100/json/" }
    let(:brasil_api) { "https://brasilapi.com.br/api/cep/v2/01310100" }

    it "fills the address from ViaCEP, with the IBGE code" do
      stub_request(:get, via_cep).to_return(body: { cep: "01310-100", logradouro: "Avenida Paulista", bairro: "Bela Vista",
        localidade: "São Paulo", uf: "SP", ibge: "3550308" }.to_json)

      expect(described_class.call("01310-100").to_h).to eq(postal_code: "01310100", street: "Avenida Paulista",
        district: "Bela Vista", city: "São Paulo", state: "SP", ibge_city_code: "3550308")
    end

    it "falls back to BrasilAPI when ViaCEP fails or does not know the CEP" do
      stub_request(:get, via_cep).to_timeout
      stub_request(:get, brasil_api).to_return(body: { cep: "01310100", street: "Avenida Paulista", neighborhood: "Bela Vista",
        city: "São Paulo", state: "SP" }.to_json)

      expect(described_class.call("01310100")).to have_attributes(city: "São Paulo", ibge_city_code: nil)
    end

    it "answers nil when neither finds it, so the HR fills by hand" do
      stub_request(:get, via_cep).to_return(body: { erro: true }.to_json)
      stub_request(:get, brasil_api).to_return(status: 404, body: "{}")

      expect(described_class.call("01310100")).to be_nil
      expect(described_class.call("123")).to be_nil
    end
  end

  describe Addresses::Geocoder do
    let(:address) { { street: "Avenida Paulista", number: "1000", city: "São Paulo", state: "SP", postal_code: "01310100" } }

    it "asks Nominatim with the application identified and returns the position" do
      request = stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
        .with(headers: { "User-Agent" => described_class::USER_AGENT })
        .to_return(body: [ { lat: "-23.5649", lon: "-46.6521" } ].to_json)

      expect(described_class.call(**address)).to have_attributes(latitude: BigDecimal("-23.5649"), longitude: BigDecimal("-46.6521"))
      expect(request.with(query: hash_including("street" => "1000 Avenida Paulista", "country" => "Brasil"))).to have_been_made
    end

    it "answers nil when the address is not found or the service fails" do
      stub_request(:get, %r{nominatim}).to_return(body: "[]")
      expect(described_class.call(**address)).to be_nil

      stub_request(:get, %r{nominatim}).to_return(status: 503)
      expect(described_class.call(**address)).to be_nil
    end
  end
end

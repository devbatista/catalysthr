module Addresses
  # Fills an address from the CEP: ViaCEP first and, if it fails, BrasilAPI. Filling by
  # hand is always possible (D-215, P-04-28). Returns nil when neither finds the CEP.
  class PostalCodeLookup
    Result = Data.define(:postal_code, :street, :district, :city, :state, :ibge_city_code)
    TIMEOUT = 3

    def self.call(postal_code)
      code = postal_code.to_s.gsub(/\D/, "")
      return unless code.match?(Unit::POSTAL_CODE_FORMAT)

      via_cep(code) || brasil_api(code)
    end

    def self.via_cep(code)
      data = get("https://viacep.com.br/ws/#{code}/json/")
      return if data.nil? || data["erro"]

      Result.new(postal_code: code, street: data["logradouro"].presence, district: data["bairro"].presence,
        city: data["localidade"].presence, state: data["uf"].presence, ibge_city_code: data["ibge"].presence)
    end

    # BrasilAPI does not return the IBGE code; the HR fills it when needed.
    def self.brasil_api(code)
      data = get("https://brasilapi.com.br/api/cep/v2/#{code}")
      return if data.nil? || data["cep"].blank?

      Result.new(postal_code: code, street: data["street"].presence, district: data["neighborhood"].presence,
        city: data["city"].presence, state: data["state"].presence, ibge_city_code: nil)
    end

    def self.get(url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, "Accept" => "application/json")
      end
      response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError
      nil
    end
    private_class_method :via_cep, :brasil_api, :get
  end
end

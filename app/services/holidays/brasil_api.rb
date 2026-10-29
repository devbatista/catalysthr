module Holidays
  # The national holidays of a year from BrasilAPI (P-11-06). BrasilAPI also lists
  # Carnival, Easter and Corpus Christi as national, so nothing it returns counts before
  # the team's review (D-638). Raises Error when the API fails, so the job tries again.
  class BrasilApi
    Error = Class.new(StandardError)
    Entry = Data.define(:date, :name)
    TIMEOUT = 10

    def self.national(year)
      uri = URI("https://brasilapi.com.br/api/feriados/v1/#{year}")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, "Accept" => "application/json")
      end
      raise Error, "BrasilAPI answered #{response.code} for #{year}" unless response.is_a?(Net::HTTPSuccess)

      items = JSON.parse(response.body)
      raise Error, "BrasilAPI answered an unexpected body for #{year}" unless items.is_a?(Array)

      items.filter_map do |item|
        next unless item.is_a?(Hash) && item["type"] == "national" && item["name"].present?

        date = Date.iso8601(item["date"].to_s)
        Entry.new(date: date, name: item["name"].to_s.squish) if date.year == year
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError,
      Date::Error => error
      raise Error, "BrasilAPI failed for #{year}: #{error.class}"
    end
  end
end

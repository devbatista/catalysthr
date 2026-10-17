module Addresses
  # Suggests the unit's position from its address with Nominatim (OpenStreetMap), within
  # its usage policy: at most one request per second for the whole application, which is
  # identified (D-216). The HR always confirms or moves the pin (RN-04-012). Returns nil
  # when the address is not found or the service does not answer.
  class Geocoder
    Result = Data.define(:latitude, :longitude)
    ENDPOINT = "https://nominatim.openstreetmap.org/search"
    USER_AGENT = "CatalystHR (https://catalysthr.com.br)"
    TIMEOUT = 5
    MIN_INTERVAL = 1.0
    # Serializes the requests of every process (pg_advisory_xact_lock).
    LOCK_KEY = 4_042_016
    LAST_REQUEST_KEY = "addresses/geocoder/last_request_at"

    def self.call(street:, number:, city:, state:, postal_code:)
      query = { street: [ number, street ].compact_blank.join(" "), city: city, state: state,
        postalcode: postal_code, country: "Brasil", format: "jsonv2", limit: 1 }.compact_blank
      return if query[:city].blank? && query[:postalcode].blank?

      data = throttled { get(query) }
      first = data&.first
      Result.new(latitude: first["lat"].to_d.round(6), longitude: first["lon"].to_d.round(6)) if first
    end

    def self.throttled
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
        last = Rails.cache.read(LAST_REQUEST_KEY)
        wait = last ? MIN_INTERVAL - (Time.current.to_f - last) : 0
        sleep(wait) if wait.positive?
        Rails.cache.write(LAST_REQUEST_KEY, Time.current.to_f, expires_in: 1.minute)
        yield
      end
    end

    def self.get(query)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(query)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, "User-Agent" => USER_AGENT, "Accept" => "application/json", "Accept-Language" => "pt-BR")
      end
      response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError
      nil
    end
    private_class_method :throttled, :get
  end
end

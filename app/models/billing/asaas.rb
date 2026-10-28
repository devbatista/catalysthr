require "net/http"

module Billing
  # Asaas's API v3, through our own client like Mercado Pago's (spec 19, section 8, P-19-37,
  # D-633): Asaas is used only for the NFS-e. The key says the environment: a sandbox key
  # ("$aact_hmlg_") talks to the sandbox, a production one ("$aact_prod_") to production, so
  # the two never mix. Nothing here logs a request or a response: they carry the client's
  # registration data.
  module Asaas
    BASE_URLS = {
      sandbox: "https://api-sandbox.asaas.com/v3",
      production: "https://api.asaas.com/v3"
    }.freeze
    KEY_PREFIXES = { "$aact_hmlg_" => :sandbox, "$aact_prod_" => :production }.freeze
    TIMEOUT = 15
    USER_AGENT = "CatalystHR".freeze
    # The note's files: only from Asaas's domain, and at most 10 MB.
    FILE_HOST = /\A([a-z0-9-]+\.)*asaas\.com\z/
    FILE_LIMIT = 10.megabytes

    # A failed call: the HTTP status (0 without an answer) and Asaas's first error, whose
    # description is in Portuguese and is shown to the finance team.
    class Error < StandardError
      attr_reader :status, :code, :description

      def initialize(message, status: 0, code: nil, description: nil)
        super(message)
        @status = status
        @code = code
        @description = description
      end

      # Worth trying again: no answer, too many requests or Asaas's own failure (RN-19-109).
      def transient?
        status.zero? || status == 429 || status >= 500
      end
    end

    module_function

    def configured?
      environment.present?
    end

    def api_key
      Rails.configuration.x.asaas_api_key
    end

    # :sandbox or :production, by the key's prefix; nil without a valid key.
    def environment
      key = api_key.to_s
      KEY_PREFIXES.find { |prefix, _| key.start_with?(prefix) }&.last
    end

    # GET /fiscalInfo: the account's fiscal setup, or nil while there is none (404).
    def fiscal_info
      request(Net::HTTP::Get, "/fiscalInfo/")
    rescue Error => e
      raise unless e.status == 404
    end

    # GET /fiscalInfo/municipalOptions: what the account's city asks (authentication,
    # cancellation, NBS).
    def municipal_options
      request(Net::HTTP::Get, "/fiscalInfo/municipalOptions")
    end

    # The customer or the note with our reference, if one was already created: Asaas
    # accepts duplicates, so a call repeated after a failure looks first.
    def find_customer(reference)
      matching("/customers", reference).first
    end

    def create_customer(body)
      request(Net::HTTP::Post, "/customers", body: body)
    end

    def update_customer(id, body)
      request(Net::HTTP::Put, "/customers/#{ERB::Util.url_encode(id)}", body: body)
    end

    # A note refused or cancelled does not count: issuing again creates another.
    def find_invoice(reference)
      matching("/invoices", reference).find { |note| !note["status"].in?(%w[ERROR CANCELED]) }
    end

    # POST /invoices: schedules the note for its effectiveDate. The answer is not the
    # city's authorization, which comes by the webhook (RN-19-106).
    def schedule_invoice(body)
      request(Net::HTTP::Post, "/invoices", body: body)
    end

    # GET /invoices/{id}: the note as it is now, with its number and files once authorized.
    def invoice(id)
      request(Net::HTTP::Get, "/invoices/#{ERB::Util.url_encode(id)}")
    end

    # The note's PDF or XML, from the address Asaas gives on the note. Only an HTTPS address
    # of Asaas's own domain is fetched, and nothing beyond FILE_LIMIT. Whether the address
    # asks for the key is not documented: it goes without it, to be checked on the first
    # real note (D-633).
    def download(url)
      uri = URI(url.to_s)
      raise Error, "Asaas file address refused" unless uri.is_a?(URI::HTTPS) && uri.host.to_s.match?(FILE_HOST)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT))
      end
      raise Error.new("Asaas file answered #{response.code}", status: response.code.to_i) unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Asaas file too large" if response.body.to_s.bytesize > FILE_LIMIT

      response.body
    rescue URI::InvalidURIError, Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "Asaas file unavailable (#{e.class})"
    end

    def matching(path, reference)
      Array(request(Net::HTTP::Get, "#{path}?#{URI.encode_www_form(externalReference: reference)}")["data"]).select do |item|
        item["externalReference"] == reference && !item["deleted"]
      end
    end

    def request(method, path, body: nil)
      raise Error, "Asaas API key is not configured" unless configured?

      uri = URI("#{BASE_URLS.fetch(environment)}#{path}")
      request = method.new(uri, "access_token" => api_key, "User-Agent" => USER_AGENT, "Accept" => "application/json")
      if body
        request["Content-Type"] = "application/json"
        request.body = body.to_json
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT,
        write_timeout: TIMEOUT) { |http| http.request(request) }
      data = response.body.present? ? JSON.parse(response.body) : {}
      return data if response.is_a?(Net::HTTPSuccess)

      error = data["errors"]&.first if data.is_a?(Hash)
      error = {} unless error.is_a?(Hash)
      raise Error.new("Asaas answered #{response.code} (#{error["code"]})", status: response.code.to_i, code: error["code"],
        description: error["description"])
    rescue JSON::ParserError, Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "Asaas unavailable (#{e.class})"
    end
  end
end

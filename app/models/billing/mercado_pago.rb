require "net/http"

module Billing
  # Mercado Pago's Orders API, through our own client (spec 19, P-19-29, D-622): creating a
  # PIX order and reading one, plus the webhook's signature. The official
  # gem would pin the app's json to the 2.x series, so it is not used. Nothing here logs a
  # request or a response: they carry the payer's e-mail.
  module MercadoPago
    BASE_URL = "https://api.mercadopago.com".freeze
    TIMEOUT = 15
    # The webhook's `ts` may be this far from the clock (the official SDKs' example).
    SIGNATURE_TOLERANCE = 300

    # A failed call: the HTTP status (0 without an answer) and Mercado Pago's error code.
    class Error < StandardError
      attr_reader :status, :code

      def initialize(message, status: 0, code: nil)
        super(message)
        @status = status
        @code = code
      end
    end

    module_function

    def configured?
      access_token.present?
    end

    def access_token
      Rails.configuration.x.mercado_pago_access_token
    end

    # POST /v1/orders. The idempotency key is required; each PIX has its own (the API
    # refuses a used key with another body, 409).
    def create_order(body, idempotency_key:)
      request(Net::HTTP::Post, "/v1/orders", body: body, headers: { "X-Idempotency-Key" => idempotency_key })
    end

    # GET /v1/orders/{id}.
    def order(id)
      request(Net::HTTP::Get, "/v1/orders/#{ERB::Util.url_encode(id)}")
    end

    def request(method, path, body: nil, headers: {})
      raise Error, "Mercado Pago access token is not configured" unless configured?

      uri = URI("#{BASE_URL}#{path}")
      request = method.new(uri, headers.merge("Authorization" => "Bearer #{access_token}", "Accept" => "application/json"))
      if body
        request["Content-Type"] = "application/json"
        request.body = body.to_json
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT,
        write_timeout: TIMEOUT) { |http| http.request(request) }
      data = response.body.present? ? JSON.parse(response.body) : {}
      return data if response.is_a?(Net::HTTPSuccess)

      code = data["errors"]&.first&.dig("code") || data["error"] if data.is_a?(Hash)
      raise Error.new("Mercado Pago answered #{response.code} (#{code})", status: response.code.to_i, code: code)
    rescue JSON::ParserError, Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "Mercado Pago unavailable (#{e.class})"
    end

    # The webhook's signature (RN-19-046): `x-signature` is "ts=<seconds>,v1=<hex>", the
    # HMAC-SHA256, with the secret from Suas integrações, of "id:<data.id>;request-id:
    # <x-request-id>;ts:<ts>;", leaving out an empty pair. As the official SDKs do; the
    # values go as received, without changing their case.
    def valid_signature?(signature, request_id, data_id, secret: Rails.configuration.x.mercado_pago_webhook_secret, now: Time.current)
      return false if secret.blank? || signature.blank?

      parts = signature.split(",").filter_map { |part| part.split("=", 2).map(&:strip) if part.include?("=") }
        .to_h.transform_keys(&:downcase)
      ts = parts["ts"]
      hash = parts["v1"]
      return false unless ts.to_s.match?(/\A\d+\z/) && hash.present?

      manifest = [ ("id:#{data_id.strip}" if data_id.present?), ("request-id:#{request_id.strip}" if request_id.present?),
        "ts:#{ts}" ].compact.join(";") + ";"
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, manifest)
      ActiveSupport::SecurityUtils.secure_compare(expected, hash) && (now.to_i - ts.to_i).abs <= SIGNATURE_TOLERANCE
    end
  end
end

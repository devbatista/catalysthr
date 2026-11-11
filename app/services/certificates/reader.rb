require "openssl"

module Certificates
  # Reads an A1 (.pfx or .p12) sent by the HR (spec 13, RN-13-020, D-673): it opens with the
  # password, carries the private key of its certificate, is within its dates, and says who
  # holds it. The ICP-Brasil chain is checked with the eSocial (spec 13, rest).
  #
  # The holder comes from the ICP-Brasil fields of the subject alternative name: 2.16.76.1.3.3
  # carries a company's CNPJ and 2.16.76.1.3.1 a person's birth date and CPF (DOC-ICP-04). An
  # e-CNPJ or e-CPF also ends its common name with ":" and the document, which is the fallback.
  class Reader
    CNPJ_OID = "2.16.76.1.3.3".freeze
    PERSON_OID = "2.16.76.1.3.1".freeze
    MAX_SIZE = 100.kilobytes

    Result = Data.define(:holder_name, :holder_document, :valid_from, :valid_to) do
      def cnpj? = holder_document.to_s.length == 14
    end

    class Invalid < StandardError
      attr_reader :key

      def initialize(key)
        @key = key
        super(key.to_s)
      end
    end

    def self.call(pfx, password, at: Time.current) = new(pfx, password, at).call

    def initialize(pfx, password, at)
      @pfx = pfx.to_s.b
      @password = password.to_s
      @at = at
    end

    def call
      raise Invalid, :too_large if @pfx.bytesize > MAX_SIZE
      raise Invalid, :blank if @pfx.empty?

      pkcs12 = open
      certificate = pkcs12.certificate
      raise Invalid, :no_key unless pkcs12.key && certificate && certificate.check_private_key(pkcs12.key)
      raise Invalid, :not_yet_valid if certificate.not_before > @at
      raise Invalid, :expired if certificate.not_after <= @at

      document = document_of(certificate)
      raise Invalid, :no_holder if document.nil?

      Result.new(holder_name: name_of(certificate), holder_document: document, valid_from: certificate.not_before,
        valid_to: certificate.not_after)
    end

    private

    def open
      self.class.load_legacy_provider
      OpenSSL::PKCS12.new(@pfx, @password)
    rescue OpenSSL::PKCS12::PKCS12Error
      raise Invalid, :unreadable
    end

    # Many A1 files of the Brazilian authorities are sealed with RC2 or 3DES, which OpenSSL 3
    # only opens with its legacy provider; the default one is loaded with it, since loading any
    # provider by hand stops the automatic one (D-673).
    def self.load_legacy_provider
      @load_legacy_provider ||= begin
        OpenSSL::Provider.load("default")
        OpenSSL::Provider.load("legacy")
        true
      end
    end

    def name_of(certificate)
      common_name(certificate).to_s.sub(/:[\dA-Z]{11,14}\z/, "").strip.presence
    end

    def common_name(certificate)
      certificate.subject.to_a.find { |name, _value, _type| name == "CN" }&.dig(1)&.force_encoding("UTF-8")
    end

    def document_of(certificate)
      from_alternative_name(certificate) || common_name(certificate).to_s[/:([\dA-Z]{14}|\d{11})\z/, 1]
    end

    # The ICP-Brasil "other names" of the subject alternative name.
    def from_alternative_name(certificate)
      extension = certificate.extensions.find { |each| each.oid == "subjectAltName" }
      return if extension.nil?

      names = OpenSSL::ASN1.decode(OpenSSL::ASN1.decode(extension.to_der).value.last.value).value
      others = names.select { |name| name.tag == 0 && name.tag_class == :CONTEXT_SPECIFIC }.filter_map { |name| other_name(name) }.to_h
      cnpj = others[CNPJ_OID]&.gsub(/[^\dA-Z]/, "")
      return cnpj if cnpj&.length == 14

      cpf = others[PERSON_OID]&.then { |value| value[8, 11] }
      cpf if cpf&.match?(/\A\d{11}\z/) && !cpf.match?(/\A0{11}\z/)
    rescue OpenSSL::ASN1::ASN1Error, NoMethodError, TypeError
      nil
    end

    def other_name(name)
      oid, value = name.value
      text = value.value.first
      text = text.value while text.respond_to?(:value) && !text.value.is_a?(String)
      [ oid.value, text.value.to_s.force_encoding("UTF-8") ]
    rescue NoMethodError, TypeError
      nil
    end
  end
end

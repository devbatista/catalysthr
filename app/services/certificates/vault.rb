require "openssl"

module Certificates
  # The A1's safe (spec 13, RN-13-020, D-075, RN-20-052, D-673): each certificate gets a data key
  # from the A1's KMS key, in São Paulo; the .pfx and its password are sealed with it in
  # AES-256-GCM and only the data key sealed by KMS is kept. The key never leaves KMS, and the
  # application's user may only ask for data keys and open them (kms:GenerateDataKey and
  # kms:Decrypt). The company's id goes in the encryption context, so a sealed certificate
  # opens only for its own company.
  #
  # Without the key's id (A1_KMS_KEY_ID), development and the specs use a local key derived from
  # the application's secret; production refuses, so nothing is sealed outside KMS.
  module Vault
    CIPHER = "aes-256-gcm".freeze
    LOCAL_KEY_ID = "local".freeze
    REGION = "sa-east-1".freeze

    Sealed = Data.define(:kms_key_id, :sealed_key, :sealed_pfx, :sealed_password)

    class NotConfigured < StandardError; end

    module_function

    def configured? = key_id.present? || !Rails.env.production?

    def key_id = Rails.configuration.x.a1_kms_key_id

    def seal(company, pfx:, password:)
      raise NotConfigured unless configured?

      plaintext, sealed_key, kms_key_id = data_key(company)
      Sealed.new(kms_key_id: kms_key_id, sealed_key: sealed_key, sealed_pfx: encrypt(plaintext, pfx),
        sealed_password: encrypt(plaintext, password))
    ensure
      plaintext&.replace("\0" * plaintext.bytesize)
    end

    # Opens the certificate for its use (the signatures of spec 10 and of spec 13), never for
    # display: yields the .pfx and the password and forgets the data key afterwards.
    def open(certificate)
      plaintext = open_key(certificate)
      yield decrypt(plaintext, certificate.sealed_pfx), decrypt(plaintext, certificate.sealed_password)
    ensure
      plaintext&.replace("\0" * plaintext.bytesize)
    end

    def data_key(company)
      if key_id.blank?
        key = SecureRandom.random_bytes(32)
        return [ key.dup, encrypt(local_key(company), key), LOCAL_KEY_ID ]
      end

      response = kms.generate_data_key(key_id: key_id, key_spec: "AES_256", encryption_context: context(company.id))
      [ response.plaintext.dup, Base64.strict_encode64(response.ciphertext_blob), response.key_id ]
    end

    def open_key(certificate)
      if certificate.kms_key_id == LOCAL_KEY_ID
        raise NotConfigured if Rails.env.production?

        return decrypt(local_key(certificate.company), certificate.sealed_key)
      end

      kms.decrypt(ciphertext_blob: Base64.strict_decode64(certificate.sealed_key), key_id: certificate.kms_key_id,
        encryption_context: context(certificate.company_id)).plaintext.dup
    end

    def encrypt(key, data)
      cipher = OpenSSL::Cipher.new(CIPHER).encrypt
      cipher.key = key
      iv = cipher.random_iv
      sealed = cipher.update(data.to_s.b) + cipher.final
      Base64.strict_encode64(iv + cipher.auth_tag + sealed)
    end

    def decrypt(key, text)
      raw = Base64.strict_decode64(text)
      cipher = OpenSSL::Cipher.new(CIPHER).decrypt
      cipher.key = key
      cipher.iv = raw.byteslice(0, 12)
      cipher.auth_tag = raw.byteslice(12, 16)
      cipher.update(raw.byteslice(28..)) + cipher.final
    end

    def context(company_id) = { "company_id" => company_id.to_s, "purpose" => "a1_certificate" }

    def local_key(company)
      Rails.application.key_generator.generate_key("a1_certificate/#{company.id}", 32)
    end

    def kms
      require "aws-sdk-kms"
      Aws::KMS::Client.new(region: REGION)
    end
  end
end

# Fictitious A1 certificates for the specs (spec 13, D-673): self-signed, with the ICP-Brasil
# field of the holder's document in the subject alternative name, or only in the common name.
module CertificateHelpers
  def a1_pfx(document: "12345678000195", name: "METALURGICA SERRA AZUL LTDA", password: "segredo", valid_from: 1.day.ago,
    valid_to: 1.year.from_now, in_alternative_name: true, legacy: false)
    rsa = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = rand(1..1_000_000)
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/C=BR/O=ICP-Brasil/CN=#{name}:#{document}")
    certificate.public_key = rsa.public_key
    certificate.not_before = valid_from
    certificate.not_after = valid_to
    if in_alternative_name
      oid = document.length == 14 ? Certificates::Reader::CNPJ_OID : Certificates::Reader::PERSON_OID
      value = document.length == 14 ? document : "01011990#{document}"
      factory = OpenSSL::X509::ExtensionFactory.new(certificate, certificate)
      certificate.add_extension(factory.create_extension("subjectAltName", "otherName:#{oid};UTF8:#{value}"))
    end
    certificate.sign(rsa, OpenSSL::Digest.new("SHA256"))
    return OpenSSL::PKCS12.create(password, "a1", rsa, certificate).to_der unless legacy

    Certificates::Reader.load_legacy_provider
    OpenSSL::PKCS12.create(password, "a1", rsa, certificate, nil, "PBE-SHA1-3DES", "PBE-SHA1-RC2-40").to_der
  end

  def a1_upload(pfx = a1_pfx, filename: "empresa.pfx")
    Rack::Test::UploadedFile.new(StringIO.new(pfx), "application/x-pkcs12", original_filename: filename)
  end
end

RSpec.configure do |config|
  config.include CertificateHelpers
end

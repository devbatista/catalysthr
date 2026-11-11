require "rails_helper"
require "aws-sdk-kms"

# Spec 13, the A1's safe and reader (RN-13-020, D-075, RN-20-052, D-673): the envelope with the
# A1's KMS key and the company in the encryption context, the refusal in production without the
# key, and the holder read from the ICP-Brasil fields. No spec calls AWS: the SDK's own stubs.
RSpec.describe "A1 certificates" do
  let(:company) { create(:company, name: "Metalúrgica Serra Azul", document: "12345678") }
  let(:key_arn) { "arn:aws:kms:sa-east-1:464986173446:key/0000-a1" }

  it "seals with a data key of the A1's KMS key, tied to the company, and opens with it (D-673)" do
    data_key = SecureRandom.random_bytes(32)
    kms = Aws::KMS::Client.new(region: "sa-east-1", stub_responses: true)
    calls = []
    kms.stub_responses(:generate_data_key, lambda { |context|
      calls << [ :generate_data_key, context.params ]
      { plaintext: data_key.dup, ciphertext_blob: "sealed-data-key", key_id: key_arn }
    })
    kms.stub_responses(:decrypt, lambda { |context|
      calls << [ :decrypt, context.params ]
      { plaintext: data_key.dup, key_id: key_arn }
    })
    allow(Certificates::Vault).to receive(:kms).and_return(kms)
    Rails.configuration.x.a1_kms_key_id = "alias/catalysthr-a1"

    sealed = Certificates::Vault.seal(company, pfx: "PFX-BYTES", password: "segredo")
    expect(sealed).to have_attributes(kms_key_id: key_arn, sealed_key: Base64.strict_encode64("sealed-data-key"))
    expect([ sealed.sealed_pfx, sealed.sealed_password ].join).not_to include("PFX-BYTES", "segredo")

    certificate = ActsAsTenant.with_tenant(company) { EmployerCertificate.new(company: company, **sealed.to_h) }
    Certificates::Vault.open(certificate) { |pfx, password| expect([ pfx, password ]).to eq(%w[PFX-BYTES segredo]) }

    context = { encryption_context: { "company_id" => company.id, "purpose" => "a1_certificate" } }
    expect(calls).to eq([
      [ :generate_data_key, { key_id: "alias/catalysthr-a1", key_spec: "AES_256", **context } ],
      [ :decrypt, { ciphertext_blob: "sealed-data-key", key_id: key_arn, **context } ]
    ])
  ensure
    Rails.configuration.x.a1_kms_key_id = nil
  end

  it "refuses to seal in production without the KMS key" do
    allow(Rails.env).to receive(:production?).and_return(true)
    expect(Certificates::Vault).not_to be_configured
    expect { Certificates::Vault.seal(company, pfx: "x", password: "y") }.to raise_error(Certificates::Vault::NotConfigured)
  end

  it "reads the holder from the alternative name, or from the common name, and refuses one without it (RN-13-020)" do
    expect(Certificates::Reader.call(a1_pfx, "segredo")).to have_attributes(holder_document: "12345678000195",
      holder_name: "METALURGICA SERRA AZUL LTDA")
    expect(Certificates::Reader.call(a1_pfx(document: "52998224725", name: "JOSE DA SILVA"), "segredo").holder_document).to eq("52998224725")
    expect(Certificates::Reader.call(a1_pfx(in_alternative_name: false), "segredo").holder_document).to eq("12345678000195")
    expect(Certificates::Reader.call(a1_pfx(legacy: true), "segredo").holder_document).to eq("12345678000195")

    expect { Certificates::Reader.call(a1_pfx(document: "X", in_alternative_name: false), "segredo") }
      .to raise_error(Certificates::Reader::Invalid, "no_holder")
    expect { Certificates::Reader.call(a1_pfx(valid_from: 1.day.from_now), "segredo") }
      .to raise_error(Certificates::Reader::Invalid, "not_yet_valid")
    expect { Certificates::Reader.call("não é um pfx", "segredo") }.to raise_error(Certificates::Reader::Invalid, "unreadable")
  end

  it "sends no notice with the flag off" do
    ActsAsTenant.with_tenant(company) do
      EmployerCertificate.create!(owner_kind: "employer", holder_document: "12345678000195", valid_from: 1.year.ago,
        valid_to: 3.days.from_now, uploaded_by: create(:user))
    end
    create(:membership, organization: company, roles: %w[hr_admin], status: "active")
    Certificates::ExpirationJob.perform_now
    expect(Notification.where(notification_type: "certificates.expiring").count).to eq(0)
  end
end

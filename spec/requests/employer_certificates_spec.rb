require "rails_helper"

# Spec 13, the A1 certificate (RN-13-020 to RN-13-022, CA-13-007, D-075, D-673): the HR
# administrator sends it with the password confirmed, the system reads the holder and the
# validity, checks whether it is the employer's or a proxy's, seals it with the KMS and erases
# the previous one; the notices of 30, 15 and 5 days and the panel's expirations.
RSpec.describe "Employer certificate", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul", document: "12345678") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }

  before do
    travel_to Time.zone.local(2026, 11, 11, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::A1_CERTIFICATE)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(hr_user, brand)
    sign_in_with_mfa(hr_user.cpf, hr_user)
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def confirm_password
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: "/settings/certificate" }
  end

  def send_certificate(pfx = a1_pfx, password: "segredo", owner_kind: "employer", filename: "empresa.pfx")
    post "/settings/certificate", params: { certificate: { file: a1_upload(pfx, filename: filename), pfx_password: password, owner_kind: owner_kind } }
  end

  it "asks the password, reads the holder and the validity, and seals the file and its password (RN-13-020, D-075)" do
    get "/settings/edit"
    expect(response.body).to include("Certificado digital A1", "/settings/certificate")
    get "/settings/certificate"
    expect(response).to redirect_to(%r{/confirm-password})
    confirm_password

    get "/settings/certificate"
    expect(response.body).to include("A empresa ainda não tem certificado digital", "Do próprio empregador", "De um procurador")

    expect { send_certificate }.to change { AccessEvent.where(kind: "certificate", action: "certificate_uploaded").count }.by(1)
    expect(flash[:notice]).to eq("Certificado salvo. Ele já vale para o eSocial e o ponto.")
    certificate = in_company { EmployerCertificate.sole }
    expect(certificate).to have_attributes(status: "active", owner_kind: "employer", holder_name: "METALURGICA SERRA AZUL LTDA",
      holder_document: "12345678000195", kms_key_id: "local", uploaded_by: hr_user)
    expect(certificate.valid_to.to_date).to eq(Date.new(2027, 11, 11))
    raw = ActiveRecord::Base.connection.select_one("SELECT sealed_pfx, sealed_password FROM employer_certificates")
    expect(raw.values.join).not_to include("segredo")
    in_company do
      Certificates::Vault.open(certificate) do |pfx, password|
        expect(password).to eq("segredo")
        expect(OpenSSL::PKCS12.new(pfx, password).certificate.subject.to_s).to include("METALURGICA SERRA AZUL LTDA")
      end
    end
    expect(PaperTrail::Version.where(item_type: "EmployerCertificate").map { |version| version.object_changes.to_s }.join).not_to include("sealed")

    get "/settings/certificate"
    expect(response.body).to include("Certificado em uso", "12.345.678/0001-95", "Válido", "Remover o certificado")
    expect(response.body).not_to include("segredo")
  end

  it "replaces the certificate and erases the previous one's file, password and key (D-673)" do
    confirm_password
    send_certificate
    first = in_company { EmployerCertificate.sole }
    send_certificate(a1_pfx(valid_to: 2.years.from_now, legacy: true))
    in_company do
      expect(first.reload).to have_attributes(status: "replaced", sealed_pfx: nil, sealed_password: nil, sealed_key: nil)
      expect(first.replaced_at).to be_present
      expect(EmployerCertificate.active.sole.valid_to.to_date).to eq(Date.new(2028, 11, 11))
    end

    expect { delete "/settings/certificate" }.to change { AccessEvent.where(action: "certificate_removed").count }.by(1)
    in_company do
      expect(EmployerCertificate.active.count).to eq(0)
      expect(EmployerCertificate.find_by!(status: "removed")).to have_attributes(removed_by: hr_user, sealed_pfx: nil)
    end
    get "/settings/certificate"
    expect(response.body).to include("Certificados anteriores", "removido por Juliana Ribeiro")
  end

  it "refuses a wrong password, an expired one, another holder for the employer and the employer as a proxy (RN-13-021)" do
    confirm_password
    send_certificate(password: "errada")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("não abriu: confira a senha")

    send_certificate(a1_pfx(valid_from: 2.years.ago, valid_to: 1.day.ago))
    expect(response.body).to include("está vencido")

    send_certificate(a1_pfx(document: "11222333000181", name: "CONTABILIDADE EXEMPLO LTDA"))
    expect(response.body).to include("não é o da empresa: o certificado é de 11.222.333/0001-81")

    send_certificate(owner_kind: "proxy")
    expect(response.body).to include("é o da própria empresa")

    send_certificate(filename: "empresa.cer")
    expect(response.body).to include("precisa ser um arquivo .pfx ou .p12")
    expect(in_company { EmployerCertificate.count }).to eq(0)

    send_certificate(a1_pfx(document: "11222333000181", name: "CONTABILIDADE EXEMPLO LTDA", in_alternative_name: false), owner_kind: "proxy")
    expect(in_company { EmployerCertificate.sole }).to have_attributes(owner_kind: "proxy", holder_document: "11222333000181")
  end

  it "takes the CPF of an employer person (RN-13-021)" do
    company.update!(employer_type: "person", document: "52998224725")
    confirm_password
    send_certificate(a1_pfx(document: "52998224725", name: "JOSE DA SILVA"))
    expect(in_company { EmployerCertificate.sole }).to have_attributes(holder_document: "52998224725", holder_name: "JOSE DA SILVA")
  end

  it "asks the password again before sending, and is only the HR administrator's" do
    confirm_password
    travel 6.minutes
    send_certificate
    expect(response).to redirect_to(%r{/confirm-password})
    expect(in_company { EmployerCertificate.count }).to eq(0)

    analyst_user = enable_mfa(create(:user, name: "Rui Costa", cpf: "39053344705"))
    create(:membership, user: analyst_user, organization: company, roles: %w[hr_analyst], status: "active")
    delete "/sign-out"
    accept_legal_documents(analyst_user, brand)
    sign_in_with_mfa(analyst_user.cpf, analyst_user)
    get "/settings/certificate"
    expect(response).to have_http_status(:forbidden)
    send_certificate
    expect(response).to have_http_status(:forbidden)
  end

  it "answers 404 with the flag off" do
    Flipper.disable(FeatureFlags::A1_CERTIFICATE)
    get "/settings/edit"
    expect(response.body).not_to include("/settings/certificate")
    get "/settings/certificate"
    expect(response).to have_http_status(:not_found)
  end

  it "tells the HR administrator 30, 15 and 5 days before, once each (RN-13-022, CA-13-007)" do
    confirm_password
    send_certificate(a1_pfx(valid_to: Time.zone.local(2026, 12, 20, 12)))
    notices = -> { Notification.where(notification_type: "certificates.expiring").order(:created_at) }

    2.times { Certificates::ExpirationJob.perform_now }
    expect(notices.call.count).to eq(0)

    travel_to Time.zone.local(2026, 11, 21, 9)
    2.times { Certificates::ExpirationJob.perform_now }
    expect(notices.call.map(&:title)).to eq([ "O certificado digital de Metalúrgica Serra Azul vence em 29 dias" ])
    expect(notices.call.sole.body).to include("eSocial", "comprovantes e o AFD do ponto")

    travel_to Time.zone.local(2026, 12, 17, 9)
    Certificates::ExpirationJob.perform_now
    expect(notices.call.count).to eq(2)
    expect(notices.call.last.title).to include("vence em 3 dias")
    expect(in_company { EmployerCertificate.sole.alerted_days }).to eq(5)
  end

  it "shows the certificate among the panel's expirations of 30 days (spec 17, D-673)" do
    confirm_password
    send_certificate(a1_pfx(valid_to: Time.zone.local(2026, 12, 1, 12)))
    expect(in_company { EmployerCertificate.sole.alerted_days }).to eq(30)
    Flipper.enable(FeatureFlags::DASHBOARDS)
    get "/dashboard/blocks/upcoming"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Certificado digital A1 · Metalúrgica Serra Azul")
    get "/upcoming-expirations"
    expect(response.body).to include("Certificado digital A1", "/settings/certificate")
  end
end

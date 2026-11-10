require "rails_helper"
require "open3"

# Spec 18, block 18e (RN-18-070 to RN-18-075, CA-18-011, CA-18-012, D-667): the HR
# administrator asks for the company's full export with the password, once a week; only who
# asked sees the ZIP's password, once, and downloads it, each download an access event.
RSpec.describe "The company's full export", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:brand) { create(:brand, owner: company, commercial_name: "Serra Azul RH") }
  let!(:hr_user) { enable_mfa(create(:user, name: "Juliana Ribeiro", cpf: "98765432100")) }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    brand.subdomains.create!(slug: "serraazul")
    Flipper.enable(FeatureFlags::SIGN_IN)
    Flipper.enable(FeatureFlags::COMPANY_EXPORT)
    publish_platform_legal_documents
    host! "serraazul.painel.catalysthr.com.br"
    accept_legal_documents(hr_user, brand)
    sign_in_with_mfa(hr_user.cpf, hr_user)
  end

  after { travel_back }

  def in_company(&) = ActsAsTenant.with_tenant(company, &)

  def confirm_password(return_to = "/data-exports")
    post "/confirm-password", params: { password: "Catalyst#2026", return_to: return_to }
  end

  def sign_in_as(user)
    delete "/sign-out"
    accept_legal_documents(user, brand)
    sign_in_with_mfa(user.cpf, user)
  end

  it "asks with the password, makes the ZIP, shows the password once and downloads it (CA-18-011)" do
    get "/"
    expect(response.body).to include("Exportação de dados", "/data-exports")

    get "/data-exports"
    expect(response.body).to include("Exportação de dados", "Pedir a exportação", "aparece uma única vez")

    post "/data-exports"
    expect(response).to redirect_to(%r{/confirm-password})
    expect(in_company { CompanyExport.count }).to eq(0)

    confirm_password
    expect do
      post "/data-exports"
    end.to change { AccessEvent.where(kind: "export", action: "company_export_requested").count }.by(1)
    export = in_company { CompanyExport.sole }
    expect(response).to redirect_to("/data-exports/#{export.id}")
    expect(export).to have_attributes(status: "queued", requested_by: hr_user, kind: "full")

    get "/data-exports/#{export.id}"
    expect(response.body).to include("Na fila", "data-reload-after")

    perform_enqueued_jobs(only: Exports::CompanyJob)
    expect(export.reload).to be_ready
    expect(Notification.where(notification_type: "exports.company_ready", recipient_user: hr_user)).to exist

    get "/data-exports/#{export.id}"
    expect(response.body).to include("Pronta. O link vale até 17/11/2026", "Mostrar a senha", "catalysthr-export-metalurgica-serra-azul-20261110.zip")
    expect(response.body).not_to include(export.password)

    stored = export.password
    expect do
      post "/data-exports/#{export.id}/password"
    end.to change { AccessEvent.where(kind: "sensitive_read", action: "company_export_password_shown").count }.by(1)
    expect(response.body).to include(stored, "Copie e guarde a senha agora")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(export.reload).to have_attributes(password: nil, password_shown_at: Time.current)

    # Once (RN-18-075).
    post "/data-exports/#{export.id}/password"
    expect(response).to redirect_to("/data-exports/#{export.id}")
    get "/data-exports/#{export.id}"
    expect(response.body).to include("A senha já foi mostrada em 10/11/2026").and(satisfy { |body| !body.include?(stored) })

    part = export.ordered_parts.sole
    expect do
      get "/data-exports/#{export.id}/parts/#{part.id}"
    end.to change { AccessEvent.where(kind: "download", action: "company_export_downloaded", subject: export).count }.by(1)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Cache-Control"]).to include("no-store")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "export.zip")
      File.binwrite(path, response.body)
      out, _err, status = Open3.capture3("7z", "l", "-p#{stored}", path)
      expect(status).to be_success
      expect(out).to include("LEIAME.txt", "indice.json", "dados/json/fichas.json", "dados/csv/fichas.csv")
    end
  end

  it "tells the day another may be asked when one was made 3 days ago (CA-18-012, RN-18-074)" do
    in_company { CompanyExport.create!(requested_by: hr_user, status: "ready", created_at: 3.days.ago) }

    get "/data-exports"
    expect(response.body).to include("A próxima exportação pode ser pedida a partir de 14/11/2026")
    expect(response.body).not_to include("Pedir a exportação")

    confirm_password
    post "/data-exports"
    expect(response).to redirect_to("/data-exports")
    expect(flash[:alert]).to eq("A empresa já pediu uma exportação nesta semana. A próxima pode ser pedida a partir de 14/11/2026.")
    expect(in_company { CompanyExport.count }).to eq(1)
  end

  it "does not count a failed export for the week (RN-18-074)" do
    in_company { CompanyExport.create!(requested_by: hr_user, status: "failed", created_at: 1.day.ago) }

    confirm_password
    post "/data-exports"
    expect(in_company { CompanyExport.count }).to eq(2)
  end

  it "shows another HR administrator the list, but not the password nor the download (D-667)" do
    export = in_company { CompanyExport.create!(requested_by: hr_user) }
    perform_enqueued_jobs { Exports::CompanyJob.perform_later(export) }
    part = export.reload.ordered_parts.sole
    other = enable_mfa(create(:user, name: "Rui Costa", cpf: "11144477735"))
    create(:membership, user: other, organization: company, roles: %w[hr_admin])
    sign_in_as(other)
    confirm_password

    get "/data-exports"
    expect(response.body).to include("Juliana Ribeiro", "Pronta")
    get "/data-exports/#{export.id}"
    expect(response.body).to include("Só quem pediu vê a senha e baixa a exportação.")
    expect(response.body).not_to include("Mostrar a senha", "/parts/")

    post "/data-exports/#{export.id}/password"
    expect(response).to have_http_status(:forbidden)
    get "/data-exports/#{export.id}/parts/#{part.id}"
    expect(response).to have_http_status(:forbidden)
    expect(export.reload.password).to be_present
  end

  it "is the HR administrator's only (spec 18, section 6)" do
    analyst = enable_mfa(create(:user, name: "Rui Costa", cpf: "11144477735"))
    create(:membership, user: analyst, organization: company, roles: %w[hr_analyst])
    sign_in_as(analyst)

    get "/"
    expect(response.body).not_to include("/data-exports")
    get "/data-exports"
    expect(response).to have_http_status(:forbidden)
    confirm_password
    post "/data-exports"
    expect(response).to have_http_status(:forbidden)
  end

  it "asks the password again before the download (RN-18-073)" do
    export = in_company { CompanyExport.create!(requested_by: hr_user) }
    perform_enqueued_jobs { Exports::CompanyJob.perform_later(export) }
    part = export.reload.ordered_parts.sole

    get "/data-exports/#{export.id}/parts/#{part.id}"
    expect(response).to redirect_to(%r{/confirm-password})
    post "/data-exports/#{export.id}/password"
    expect(response).to redirect_to(%r{/confirm-password})
    expect(export.reload.password).to be_present
  end

  it "answers 404 with the flag off, and the menu does not show it (D-667)" do
    Flipper.disable(FeatureFlags::COMPANY_EXPORT)

    get "/"
    expect(response.body).not_to include("/data-exports")
    get "/data-exports"
    expect(response).to have_http_status(:not_found)
  end

  it "does not open another company's export (spec 01)" do
    other_company = create(:company, name: "Padaria Pão Quente")
    baker = create(:user, name: "Rita Souza")
    create(:membership, user: baker, organization: other_company, roles: %w[hr_admin])
    export = ActsAsTenant.with_tenant(other_company) { CompanyExport.create!(requested_by: baker) }

    get "/data-exports/#{export.id}"
    expect(response).to have_http_status(:not_found)
  end
end

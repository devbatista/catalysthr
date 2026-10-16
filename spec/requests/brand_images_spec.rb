require "rails_helper"

# Spec 01, RN-01-014, RN-01-030, RN-01-033 and RN-01-034: the brand's images, stored
# under the owner's prefix and served only by the application.
RSpec.describe "Brand images", type: :request do
  let(:partner) { create(:partner) }
  let!(:brand) { create(:brand, owner: partner, commercial_name: "Aurora RH") }
  let!(:padaria) { create(:company, partner: partner, name: "Padaria Pão Quente") }
  let!(:admin) { enable_mfa(create(:user, cpf: "98765432100")) }

  before do
    create(:membership, user: admin, organization: partner, roles: %w[partner_admin])
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
    publish_platform_legal_documents
    accept_legal_documents(admin, brand)
    host! "aurora.painel.catalysthr.com.br"
  end

  def logo
    fixture_file_upload("logo.png", "image/png")
  end

  def sign_in_admin
    sign_in_with_mfa("98765432100", admin)
  end

  it "uploads the partner's logo under the partner's prefix and shows it at the sign-in, served by the application" do
    sign_in_admin
    patch "/partner/brand", params: { brand: { commercial_name: "Aurora RH" }, brand_images: { logo_light: logo, pwa_icon_large: logo } }

    expect(response).to redirect_to("/partner/brand/edit")
    expect(brand.reload.logo_light.blob.key).to start_with("partners/#{partner.id}/brand/logo_light/")

    delete "/sign-out"
    get "/sign-in"
    expect(response.body).to include("/brand-assets/logo_light?v=#{brand.logo_light.blob_id}")

    get "/brand-assets/logo_light"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(response.body.bytesize).to eq(brand.logo_light.blob.byte_size)
    expect(response.headers["Cache-Control"]).to include("public")

    get "/brand-assets/logo_light", headers: { "If-None-Match" => response.headers["ETag"] }
    expect(response).to have_http_status(:not_modified)

    get "/manifest.webmanifest"
    expect(JSON.parse(response.body)["icons"].first["src"]).to start_with("/brand-assets/pwa_icon_large?v=")
  end

  it "refuses a file that is not an image, from its content, and uploads nothing" do
    sign_in_admin

    patch "/partner/brand", params: { brand: { commercial_name: "Aurora RH" }, brand_images: { logo_light: fixture_file_upload("fake.png", "image/png") } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("precisa ser uma imagem PNG, JPEG ou WebP")
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it "removes an image" do
    brand.logo_light.attach(io: File.open(file_fixture("logo.png")), filename: "logo.png", content_type: "image/png")
    sign_in_admin

    patch "/partner/brand", params: { brand: { commercial_name: "Aurora RH" }, remove_images: %w[logo_light] }

    expect(brand.reload.logo_light).not_to be_attached
  end

  it "stores the client company's logo under the company's prefix and shows it in the header in alongside mode" do
    sign_in_admin
    patch "/partner/companies/#{padaria.id}/brand", params: { brand: { commercial_name: "Padaria" }, brand_images: { logo_light: logo },
      brand_display_mode: "alongside" }

    expect(padaria.reload.brand.logo_light.blob.key).to start_with("companies/#{padaria.id}/brand/logo_light/")

    hr_admin = enable_mfa(create(:user, cpf: "11144477735"))
    create(:membership, user: hr_admin, organization: padaria, roles: %w[hr_admin])
    accept_legal_documents(hr_admin, brand)
    delete "/sign-out"
    sign_in_with_mfa("11144477735", hr_admin)

    get "/"
    expect(response.body).to include("/brand-assets/company/logo_light?v=")
    get "/brand-assets/company/logo_light"
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("private")
  end

  it "does not serve a company's logo without sign-in, nor an unknown kind" do
    get "/brand-assets/company/logo_light"
    expect(response).to redirect_to("/sign-in")

    get "/brand-assets/secrets"
    expect(response).to have_http_status(:not_found)
  end

  it "keeps Active Storage's public blob routes off (RN-01-014)" do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:rails_blob_path)
  end
end

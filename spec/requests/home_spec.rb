require "rails_helper"

RSpec.describe "Home", type: :request do
  it "renders the placeholder page in Portuguese" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Plataforma em construção.")
    expect(response.body).to include('lang="pt-BR"')
  end

  it "answers the health check" do
    get rails_health_check_path

    expect(response).to have_http_status(:ok)
  end
end

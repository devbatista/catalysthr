require "rails_helper"

# Spec 05, section 8: CSP without inline scripts and security headers (P-05-29, D-606).
RSpec.describe "Content security policy", type: :request do
  let(:brand) { create(:brand, owner: create(:partner), commercial_name: "Aurora RH") }

  before do
    brand.subdomains.create!(slug: "aurora")
    Flipper.enable(FeatureFlags::SIGN_IN)
  end

  def policy
    response.headers["Content-Security-Policy"].split(";").to_h { |directive| directive.strip.split(" ", 2) }
  end

  def nonce = policy.fetch("script-src")[/'nonce-([^']+)'/, 1]

  it "allows only the app's scripts and styles, with the request's nonce, in the brand's panel" do
    host! "aurora.painel.catalysthr.com.br"
    get "/sign-in"

    expect(policy).to include("default-src" => "'self'", "object-src" => "'none'", "frame-ancestors" => "'none'",
      "img-src" => "'self' data: https://tile.openstreetmap.org")
    expect(policy.fetch("script-src")).to match(/\A'self' 'nonce-[^']+'\z/)
    expect(policy.fetch("style-src")).to eq("'self' 'nonce-#{nonce}'")
    expect(response.body).to include(%(<style nonce="#{nonce}">), %(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}">))
    expect(response.headers).to include("X-Frame-Options" => "DENY", "Referrer-Policy" => "strict-origin-when-cross-origin")
  end

  it "changes the nonce on every request and covers the admin" do
    host! "admin.catalysthr.com.br"
    get "/sign-in"
    first = nonce
    expect(response.body).to include(%(nonce="#{first}"))

    get "/sign-in"
    expect(nonce).not_to eq(first)
  end
end

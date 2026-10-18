require "rails_helper"

# The CSP blocks style attributes, event handler attributes and inline scripts or
# styles without the request's nonce (P-05-29, D-606). E-mails are not under the CSP.
RSpec.describe "Inline code in views" do
  views = Dir[Rails.root.join("app/views/**/*.erb")].reject { |path| path.include?("/layouts/mailer") || path.include?("_mailer/") }

  it "has no style or event handler attributes" do
    offenders = views.select { |path| File.read(path).match?(/\s(style|on[a-z]+)=["']/) }

    expect(offenders).to be_empty
  end

  it "gives every inline script and style the request's nonce" do
    offenders = views.select { |path| File.read(path).scan(/<(?:script|style)\b[^>]*>/).any? { |tag| !tag.include?("content_security_policy_nonce") } }

    expect(offenders).to be_empty
  end
end

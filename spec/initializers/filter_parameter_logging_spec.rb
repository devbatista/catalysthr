require "rails_helper"

RSpec.describe "Filtered parameters" do
  it "hides the sign-in field, which holds a CPF or an e-mail (RN-02-003)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("user" => { "login" => "123.456.789-09", "password" => "Catalyst#2026" }))
      .to eq("user" => { "login" => "[FILTERED]", "password" => "[FILTERED]" })
  end

  it "hides the MFA and recovery codes (RN-02-042)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("otp_code" => "a1b2c3d4e5")).to eq("otp_code" => "[FILTERED]")
  end
end

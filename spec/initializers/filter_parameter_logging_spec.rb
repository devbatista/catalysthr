require "rails_helper"

RSpec.describe "Filtered parameters" do
  it "hides the sign-in field, which holds a CPF or an e-mail (RN-02-003)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("user" => { "login" => "123.456.789-09", "password" => "Catalyst#2026" }))
      .to eq("user" => { "login" => "[FILTERED]", "password" => "[FILTERED]" })
  end
end

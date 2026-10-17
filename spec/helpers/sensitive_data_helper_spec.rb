require "rails_helper"

# Spec 05, RN-05-001 and RN-05-020; spec 02, RN-02-052 and RN-02-087 (D-592).
RSpec.describe SensitiveDataHelper, type: :helper do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:profile) { register_employee(company, by: hr_admin, position: create_position(company)) }

  before do
    ActsAsTenant.with_tenant(company) { profile.update!(rg_number: "123456789") }
    Current.company = company
    viewer = hr_admin
    helper.define_singleton_method(:revealed_sections) { [ "documents" ] }
    helper.define_singleton_method(:current_user) { viewer }
  end

  it "hides a section not asked for" do
    expect(helper.reveal_confirmed(profile, :rg_number, as: :text, section: :health)).to eq("••••••")
    expect(AccessEvent.where(kind: "sensitive_read")).to be_empty
  end

  it "shows a revealed value and records it once per field in the request (RN-05-020)" do
    2.times { expect(helper.reveal_confirmed(profile, :rg_number, as: :text, section: :documents)).to eq("123456789") }

    expect(AccessEvent.where(kind: "sensitive_read").pluck(:field, :action, :user_id)).to eq([ [ "rg_number", "view", hr_admin.id ] ])
  end

  it "masks the value during an impersonate, without a read event (RN-02-087)" do
    Current.impersonation = build(:impersonation_session)

    expect(helper.reveal_confirmed(profile, :rg_number, as: :text, section: :documents)).to eq("••••••")
    expect(helper.reveal_confirmed(profile, :rg_number, as: :money, section: :documents, value: 250_000)).to eq("R$ ••••")
    expect(AccessEvent.where(kind: "sensitive_read")).to be_empty
  end
end

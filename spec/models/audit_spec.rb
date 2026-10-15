require "rails_helper"

# Spec 05: change trail (RN-05-010, RN-05-011) and access events (RN-05-022).
RSpec.describe "Audit" do
  let(:company) { create(:company) }

  def raw_versions
    PaperTrail::Version.connection.select_values("SELECT concat(object::text, object_changes::text) FROM versions").join
  end

  it "records who changed a company, with the request data" do
    PaperTrail.request(whodunnit: "42", controller_info: { ip: "10.0.0.1", request_id: "abc" }) do
      company.update!(name: "Metalúrgica Serra Azul Matriz")
    end

    version = company.versions.last
    expect(version).to have_attributes(event: "update", whodunnit: "42", ip: "10.0.0.1", request_id: "abc", company_id: company.id)
    expect(version.object_changes["name"]).to eq([ "Metalúrgica Serra Azul", "Metalúrgica Serra Azul Matriz" ])
  end

  it "ties a company membership's versions to the company" do
    membership = create(:membership, organization: company)

    expect(membership.versions.last.company_id).to eq(company.id)
  end

  describe "sensitive fields (RN-05-011)" do
    let!(:user) { create(:user, cpf: "12345678909", name: "Maria Souza") }

    it "never writes the CPF in the trail, only that it changed" do
      user.update!(cpf: "52998224725")
      only_cpf = user.versions.last

      user.update!(cpf: "11144477735", name: "Maria Souza Lima")
      with_name = user.versions.last

      expect(only_cpf).to have_attributes(event: "update", sensitive_fields: [ "cpf" ], object_changes: {})
      expect(with_name.sensitive_fields).to eq([ "cpf" ])
      expect(with_name.object_changes.keys).to include("name")
      expect(raw_versions).not_to include("12345678909", "52998224725", "11144477735")
    end

    it "keeps secrets and sign-in bookkeeping out of the trail" do
      expect { user.update!(password: "Nova#Senha2026") }.not_to change(PaperTrail::Version, :count)
      expect { user.update!(sign_in_count: 3, current_sign_in_ip: "10.0.0.1") }.not_to change(PaperTrail::Version, :count)
      expect(raw_versions).not_to include(user.encrypted_password)
    end
  end

  it "keeps access events insert only (RN-05-022)" do
    event = AccessEvent.record!(kind: "auth", action: "sign_in", user: create(:user))

    expect { event.update!(action: "outro") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end

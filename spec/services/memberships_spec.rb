require "rails_helper"

# Spec 02, RN-02-060 to RN-02-063; spec 03, RN-03-012 and RN-03-013.
RSpec.describe Memberships do
  let(:company) { create(:company) }
  let(:actor) { create(:user) }

  describe Memberships::UpdateAccess do
    it "changes roles and modules, recording each change (RN-05-020)" do
      membership = create(:membership, organization: company, roles: %w[manager])

      described_class.call(membership: membership, roles: %w[hr_analyst], enabled_modules: %w[admissao documentos], by: actor)

      expect(membership.reload).to have_attributes(roles: %w[hr_analyst], enabled_modules: %w[admissao documentos])
      events = AccessEvent.where(kind: "admin", subject: membership)
      expect(events.pluck(:action)).to contain_exactly("roles_changed", "modules_changed")
      expect(events.find_by(action: "roles_changed").metadata).to eq("from" => %w[manager], "to" => %w[hr_analyst])
    end

    it "drops the modules of a role that no longer uses them" do
      membership = create(:membership, organization: company, roles: %w[hr_analyst], enabled_modules: %w[folha])

      described_class.call(membership: membership, roles: %w[manager], enabled_modules: %w[folha], by: actor)

      expect(membership.reload.enabled_modules).to be_empty
    end

    it "keeps a direct company with an active HR administrator (RN-03-013)" do
      only_admin = create(:membership, organization: company, roles: %w[hr_admin])

      expect { described_class.call(membership: only_admin, roles: %w[manager], enabled_modules: [], by: actor) }
        .to raise_error(ActiveRecord::RecordInvalid, /pelo menos um RH administrador/)
    end

    it "lets a partner's company go without one, because the partner serves it" do
      membership = create(:membership, organization: create(:company, :with_partner), roles: %w[hr_admin])

      described_class.call(membership: membership, roles: %w[manager], enabled_modules: [], by: actor)

      expect(membership.reload.roles).to eq(%w[manager])
    end
  end

  describe Memberships::Revoke do
    it "removes the access and deactivates an account left without memberships (RN-02-062)" do
      create(:membership, organization: company, roles: %w[hr_admin])
      membership = create(:membership, organization: company, roles: %w[manager])

      described_class.call(membership: membership, by: actor)

      expect(membership.reload).to be_revoked
      expect(membership.user.reload).to be_deactivated
      expect(AccessEvent.find_by!(subject: membership).action).to eq("access_revoked")
    end

    it "keeps the account of who still has another membership" do
      membership = create(:membership, organization: company, roles: %w[manager])
      create(:membership, user: membership.user, organization: create(:company))

      described_class.call(membership: membership, by: actor)

      expect(membership.user.reload).to be_active
    end

    it "cancels a pending invitation" do
      membership = create(:membership, organization: company, roles: %w[manager], status: "invited")

      described_class.call(membership: membership, by: actor)

      expect(AccessEvent.find_by!(subject: membership).action).to eq("invitation_cancelled")
    end

    it "cancels the invitation of an HR administrator, which does not count as an active one" do
      create(:membership, organization: company, roles: %w[hr_admin])
      invited = create(:membership, organization: company, roles: %w[hr_admin], status: "invited")

      described_class.call(membership: invited, by: actor)

      expect(invited.reload).to be_revoked
    end
  end

  describe "the last administrator of a partner or an accounting firm (D-584)" do
    let(:partner) { create(:partner) }

    it "keeps the partner's last active administrator" do
      only_admin = create(:membership, organization: partner, roles: %w[partner_admin consultant])
      create(:membership, organization: partner, roles: %w[partner_admin], status: "invited")

      expect { Memberships::Revoke.call(membership: only_admin, by: actor) }
        .to raise_error(ActiveRecord::RecordInvalid, /pelo menos um administrador ativo/)
      expect { Memberships::UpdateAccess.call(membership: only_admin, roles: %w[consultant], enabled_modules: [], by: actor) }
        .to raise_error(ActiveRecord::RecordInvalid, /pelo menos um administrador ativo/)
      expect(only_admin.reload).to have_attributes(status: "active", roles: %w[partner_admin consultant])
    end

    it "keeps the accounting firm's last active administrator" do
      only_admin = create(:membership, organization: create(:accounting_firm), roles: %w[firm_admin])

      expect { Memberships::Revoke.call(membership: only_admin, by: actor) }
        .to raise_error(ActiveRecord::RecordInvalid, /escritório precisa de pelo menos um administrador ativo/)
    end

    it "lets an administrator go while another one stays" do
      create(:membership, organization: partner, roles: %w[partner_admin])
      leaving = create(:membership, organization: partner, roles: %w[partner_admin])

      Memberships::Revoke.call(membership: leaving, by: actor)

      expect(leaving.reload).to be_revoked
    end
  end

  describe Memberships::AssignCompanies do
    let(:partner) { create(:partner) }
    let(:consultant) { create(:membership, organization: partner, roles: %w[consultant]) }

    it "assigns only the partner's companies (D-052)" do
      own = create(:company, partner: partner)
      foreign = create(:company, :with_partner)

      described_class.call(membership: consultant, company_ids: [ own.id, foreign.id ], by: actor)

      expect(consultant.assigned_companies).to contain_exactly(own)
    end

    it "records nothing when the companies stay the same" do
      described_class.call(membership: consultant, company_ids: [], by: actor)

      expect(AccessEvent.where(action: "companies_assigned")).to be_empty
    end
  end
end

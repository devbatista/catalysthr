require "rails_helper"

# P-03-12, RN-19-012, RN-19-031, CA-19-003, D-616: the modules a company may use come
# from its contract.
RSpec.describe CompanyModules do
  let(:core) { %w[admissao documentos solicitacoes recrutamento avaliacao] }

  it "gives a direct company the contracted modules, payroll with eSocial" do
    company = create(:company)
    contract_for(company, modules: %w[folha])

    modules = described_class.new(company)
    expect(modules.contracted).to eq(%w[folha])
    expect(modules.state("folha")).to eq(:usable)
    expect(modules.state("ponto")).to be_nil
    expect(modules.releasable).to match_array(core + %w[folha esocial])
  end

  it "keeps time tracking and eSocial for after the contract during the trial and after it (RN-19-031, CA-19-003)" do
    company = create(:company)
    subscription = contract_for(company, status: "trialing")

    %w[trialing trial_expired].each do |status|
      subscription.update_columns(status: status)
      modules = described_class.new(company.reload)
      expect(modules.state("ponto")).to eq(:after_contract)
      expect(modules.state("folha")).to eq(:usable)
      expect(modules.releasable).to match_array(core + %w[folha])
    end
  end

  it "gives a partner's company only the partner's modules turned on for it (RN-19-012)" do
    partner = create(:partner)
    company = create(:company, partner: partner)
    contract_for(partner, modules: %w[ponto])

    expect(described_class.new(company).contracted).to be_empty

    turn_on_modules(company, %w[ponto folha])
    expect(company.module_settings.pluck(:module)).to eq(%w[ponto])
    expect(described_class.new(company).contracted).to eq(%w[ponto])
  end

  it "gives no modules without a contract or with a closed one" do
    company = create(:company)
    expect(described_class.new(company).releasable).to match_array(core)

    contract_for(company).update!(status: "closed")
    expect(described_class.new(company.reload).releasable).to match_array(core)
  end
end

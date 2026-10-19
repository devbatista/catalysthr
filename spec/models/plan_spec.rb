require "rails_helper"

# Spec 19, RN-19-010, RN-19-013 and RN-19-014: plans, add-ons and their price versions
# (D-611).
RSpec.describe Plan do
  describe "price versions (RN-19-014, D-611)" do
    let(:plan) { create(:plan) }

    it "numbers the versions of each plan" do
      first = create(:plan_version, plan: plan)
      second = create(:plan_version, plan: plan, valid_from: 1.month.from_now.to_date)

      expect([ first.version, second.version ]).to eq([ 1, 2 ])
      expect(create(:plan_version, plan: create(:plan)).version).to eq(1)
    end

    it "never changes a saved version, nor its modules' prices" do
      version = create(:plan_version, plan: plan)

      expect { version.update!(monthly_price_cents: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { version.plan_modules.first.update!(price_cents: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "uses the latest version that started by the date, and the last registered between versions of the same date" do
      travel_to Date.new(2026, 10, 1) do
        create(:plan_version, plan: plan, monthly_price_cents: 100_000)
        create(:plan_version, plan: plan, valid_from: Date.new(2026, 11, 1), monthly_price_cents: 120_000)
        create(:plan_version, plan: plan, valid_from: Date.new(2026, 11, 1), monthly_price_cents: 110_000)
      end
      plan.reload

      expect(plan.version_on(Date.new(2026, 10, 31)).monthly_price_cents).to eq(100_000)
      expect(plan.version_on(Date.new(2026, 11, 1)).monthly_price_cents).to eq(110_000)
      expect(plan.version_on(Date.new(2026, 9, 30))).to be_nil
    end

    it "refuses a version that starts in the past" do
      version = build(:plan_version, plan: plan, valid_from: Date.yesterday)

      expect(version).not_to be_valid
      expect(version.errors[:valid_from]).to include("não pode ser uma data passada")
    end

    it "requires the partner fields in a partner plan and keeps out the direct ones (D-480)" do
      version = build(:plan_version, plan: plan, price_per_employee_cents: 1_000)
      version.monthly_price_cents = nil
      version.employee_limit = 0

      expect(version).not_to be_valid
      expect(version.errors[:monthly_price_cents]).to be_present
      expect(version.errors[:employee_limit]).to be_present
      expect(version.price_per_employee_cents).to be_nil
    end

    it "requires the per-employee price, the minimum and the quotas per employee in a direct plan (D-122)" do
      version = build(:plan_version, plan: create(:plan, :direct), monthly_price_cents: 100_000)
      version.minimum_monthly_cents = nil
      version.ai_credits_per_employee = nil

      expect(version).not_to be_valid
      expect(version.errors[:minimum_monthly_cents]).to be_present
      expect(version.errors[:ai_credits_per_employee]).to be_present
      expect(version.monthly_price_cents).to be_nil
    end

    it "takes amounts typed in reais and refuses what is not an amount" do
      version = build(:plan_version, plan: plan)
      version.monthly_price = "1.500,50"
      version.overage_per_employee = "três reais"

      expect(version).not_to be_valid
      expect(version.monthly_price_cents).to eq(150_050)
      expect(version.errors[:overage_per_employee_cents]).to eq([ "precisa ser um valor em reais, como 2.500,00" ])
    end

    it "requires the price of both modules (D-111)" do
      version = build(:plan_version, plan: plan)
      version.module_prices = { "ponto" => "400,00", "folha" => "" }

      expect(version).not_to be_valid
      expect(version.errors[:base]).to include("O preço do módulo Folha não pode ficar em branco")
    end
  end

  it "does not repeat a name within the same kind" do
    create(:plan, name: "Até 500 colaboradores")

    expect(build(:plan, name: "até 500  colaboradores")).not_to be_valid
    expect(build(:plan, :direct, name: "Até 500 colaboradores")).to be_valid
  end

  it "keeps plan and version changes in the trail (RN-19-070's audit, spec 05)" do
    version = PaperTrail.request(whodunnit: "7") { create(:plan_version) }

    expect(version.plan.versions.last).to have_attributes(event: "create", whodunnit: "7")
    expect(version.versions.last).to have_attributes(event: "create", whodunnit: "7")
  end

  describe AddOnPrice do
    it "numbers the prices and uses the last registered between prices of the same date (D-611)" do
      add_on = create(:add_on)
      travel_to Date.new(2026, 10, 1) do
        create(:add_on_price, add_on: add_on, monthly_price_cents: 9_900)
        create(:add_on_price, add_on: add_on, valid_from: Date.new(2026, 12, 1), monthly_price_cents: 12_900)
        create(:add_on_price, add_on: add_on, valid_from: Date.new(2026, 12, 1), monthly_price_cents: 11_900)
      end
      add_on.reload

      expect(add_on.prices.map(&:version)).to eq([ 1, 2, 3 ])
      expect(add_on.price_on(Date.new(2026, 11, 30)).monthly_price_cents).to eq(9_900)
      expect(add_on.price_on(Date.new(2026, 12, 1)).monthly_price_cents).to eq(11_900)
      expect { add_on.prices.first.update!(monthly_price_cents: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end

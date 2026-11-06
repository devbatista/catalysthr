require "rails_helper"

# Spec 15, block 15c (RN-15-031, D-654): from 20h to 8h, weekends and the unit's holidays, in
# the unit's time zone. The unit is the employment's, or the headquarters, or Brasília.
RSpec.describe Notifications::QuietHours do
  let(:company) { create(:company) }
  let(:membership) { create(:membership, organization: company, roles: %w[hr_admin]) }
  let(:headquarters) { company.headquarters }
  let(:zone) { ActiveSupport::TimeZone["America/Sao_Paulo"] }

  def release(time, member = membership) = described_class.release_at(member, now: zone.parse(time))

  # 2026-11-04 is a Wednesday.
  it "lets the notice leave at once within the hours" do
    expect(release("2026-11-04 08:00")).to be_nil
    expect(release("2026-11-04 19:59")).to be_nil
  end

  it "holds until 8h of the next business day at night and on weekends (CA-15-001)" do
    expect(release("2026-11-04 20:00")).to eq(zone.parse("2026-11-05 08:00"))
    expect(release("2026-11-04 07:59")).to eq(zone.parse("2026-11-04 08:00"))
    expect(release("2026-11-06 21:00")).to eq(zone.parse("2026-11-09 08:00"))
    expect(release("2026-11-07 12:00")).to eq(zone.parse("2026-11-09 08:00"))
    expect(release("2026-11-08 12:00")).to eq(zone.parse("2026-11-09 08:00"))
    expect(release("2026-11-09 06:00")).to eq(zone.parse("2026-11-09 08:00"))
  end

  it "skips the unit's holidays" do
    ActsAsTenant.with_tenant(company) { UnitHoliday.create!(unit: headquarters, date: "2026-11-05", name: "Dia da cidade", kind: "holiday", created_by: membership.user) }

    expect(release("2026-11-04 21:00")).to eq(zone.parse("2026-11-06 08:00"))
    expect(release("2026-11-05 12:00")).to eq(zone.parse("2026-11-06 08:00"))
  end

  it "uses the unit's time zone: 20h30 in Brasília is 19h30 in Manaus" do
    ActsAsTenant.with_tenant(company) { headquarters.update!(time_zone: "America/Manaus") }

    expect(release("2026-11-04 20:30")).to be_nil
    manaus = ActiveSupport::TimeZone["America/Manaus"]
    expect(release("2026-11-04 21:00")).to eq(manaus.parse("2026-11-05 08:00"))
  end

  it "uses the unit of the current employment before the headquarters" do
    unit = ActsAsTenant.with_tenant(company) { Unit.create!(name: "Manaus", time_zone: "America/Manaus") }
    profile = register_employee(company, by: membership.user, position: create_position(company), unit: unit)

    expect(release("2026-11-04 20:30", profile.membership)).to be_nil
    expect(release("2026-11-04 20:30")).to eq(zone.parse("2026-11-05 08:00"))
  end

  it "uses Brasília and the national holidays without a company" do
    partner_membership = create(:membership, organization: create(:partner), roles: %w[partner_admin])

    expect(release("2026-11-04 21:00", partner_membership)).to eq(zone.parse("2026-11-05 08:00"))
    expect(release("2026-11-04 21:00", nil)).to eq(zone.parse("2026-11-05 08:00"))
  end
end

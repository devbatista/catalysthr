require "rails_helper"

# Spec 06, block 06a (RN-06-025, RN-06-026, RN-06-029, CA-06-003) and spec 11 (RN-11-020,
# P-11-06), with D-638: the holidays and the business days. Recorded answers only; no test
# reaches BrasilAPI.
RSpec.describe "Holidays" do
  let(:brasil_api) { "https://brasilapi.com.br/api/feriados/v1/2027" }
  let(:company) { create(:company) }
  let(:author) { create(:user) }

  def national(date, name, **attributes)
    Holiday.create!(level: "national", date: Date.parse(date), name: name, **attributes)
  end

  def unit(**attributes)
    ActsAsTenant.with_tenant(company) { Unit.create!(name: "Filial Caxias", **attributes) }
  end

  def unit_day(unit, **attributes)
    ActsAsTenant.with_tenant(company) { UnitHoliday.create!(unit: unit, created_by: author, **attributes) }
  end

  def calendar(unit = nil)
    Holidays::Calendar.new(unit)
  end

  describe Holiday do
    it "keeps the place each level needs" do
      expect(described_class.new(level: "national", state: "RS", ibge_city_code: "4305108", city_name: "Caxias", date: Date.current,
        name: "Natal").tap(&:validate)).to have_attributes(state: nil, ibge_city_code: nil, city_name: nil)
      expect(described_class.new(level: "state", date: Date.current, name: "Revolução Farroupilha"))
        .to have_attributes(valid?: false)
      city = described_class.new(level: "city", state: "RS", ibge_city_code: "430510", date: Date.current, name: "Padroeiro")
      expect(city).not_to be_valid
      expect(city.errors.attribute_names).to include(:ibge_city_code, :city_name)
    end

    it "allows turning off in a unit only a national holiday (D-638)" do
      holiday = described_class.new(level: "state", state: "RS", date: Date.current, name: "Farroupilha", unit_opt_out: true)

      expect(holiday).not_to be_valid
      expect(holiday.errors[:unit_opt_out]).to eq([ "só vale para feriado nacional" ])
    end

    it "refuses two holidays on the same date in the same place" do
      national("2027-12-25", "Natal")

      expect(described_class.new(level: "national", date: Date.new(2027, 12, 25), name: "Natal")).not_to be_valid
      expect(described_class.new(level: "state", state: "RS", date: Date.new(2027, 12, 25), name: "Natal")).to be_valid
    end
  end

  describe Holidays::BrasilApi do
    it "reads the national holidays of the year" do
      stub_request(:get, brasil_api).to_return(body: [
        { date: "2027-04-21", name: "Tiradentes", type: "national" },
        { date: "2027-06-26", name: "Outro", type: "state" },
        { date: "2026-12-25", name: "Natal", type: "national" }
      ].to_json)

      expect(described_class.national(2027)).to eq([ described_class::Entry.new(date: Date.new(2027, 4, 21), name: "Tiradentes") ])
    end

    it "raises when BrasilAPI fails, so the job tries again" do
      stub_request(:get, brasil_api).to_return(status: 500)
      expect { described_class.national(2027) }.to raise_error(described_class::Error, /500/)

      stub_request(:get, brasil_api).to_timeout
      expect { described_class.national(2027) }.to raise_error(described_class::Error)

      stub_request(:get, brasil_api).to_return(body: { message: "erro" }.to_json)
      expect { described_class.national(2027) }.to raise_error(described_class::Error)
    end
  end

  describe Holidays::ImportNational do
    before do
      stub_request(:get, brasil_api).to_return(body: [
        { date: "2027-02-08", name: "Carnaval", type: "national" },
        { date: "2027-03-26", name: "Sexta-feira Santa", type: "national" },
        { date: "2027-11-15", name: "Proclamação da República", type: "national" }
      ].to_json)
    end

    it "brings the holidays for review, with Good Friday allowed to be turned off (P-11-06, D-638)" do
      created = described_class.call(2027)

      expect(created.map(&:name)).to eq([ "Carnaval", "Sexta-feira Santa", "Proclamação da República" ])
      expect(Holiday.all).to all(have_attributes(status: "pending", source: "brasil_api", level: "national"))
      expect(Holiday.where(unit_opt_out: true).pluck(:name)).to eq([ "Sexta-feira Santa" ])
    end

    it "does not propose again a date already there, published or rejected" do
      national("2027-11-15", "Proclamação da República")
      described_class.call(2027)
      Holiday.find_by!(name: "Carnaval").review!("rejected", by: author)

      expect(described_class.call(2027)).to be_empty
      expect(Holiday.count).to eq(3)
      expect(Holiday.find_by!(name: "Carnaval")).to be_rejected
    end
  end

  describe Holidays::Calendar do
    # The unit's own days are read inside its company.
    around { |example| ActsAsTenant.with_tenant(company) { example.run } }

    before do
      national("2027-11-15", "Proclamação da República")
      national("2027-11-20", "Dia da consciência negra")
      national("2027-02-08", "Carnaval", status: "rejected")
      national("2027-03-26", "Sexta-feira Santa", unit_opt_out: true)
      national("2027-05-27", "Corpus Christi", status: "pending")
    end

    # CA-06-003: "3 business days before the start", the start on November 15th, a national
    # holiday; and a start right after it, where the holiday is skipped.
    it "counts business days around a national holiday (CA-06-003)" do
      calendar = calendar()

      expect(calendar.shift(Date.new(2027, 11, 15), -3, business: true)).to eq(Date.new(2027, 11, 10))
      expect(calendar.shift(Date.new(2027, 11, 16), -3, business: true)).to eq(Date.new(2027, 11, 10))
      expect(calendar.shift(Date.new(2027, 11, 12), 1, business: true)).to eq(Date.new(2027, 11, 16))
      expect(calendar.shift(Date.new(2027, 11, 12), 3, business: false)).to eq(Date.new(2027, 11, 15))
    end

    it "counts only the published holidays (P-11-06)" do
      calendar = calendar()

      expect(calendar.holiday?(Date.new(2027, 11, 15))).to be(true)
      expect(calendar.holiday?(Date.new(2027, 2, 8))).to be(false)
      expect(calendar.holiday?(Date.new(2027, 5, 27))).to be(false)
    end

    it "adds the unit's state and city holidays and its own, never an optional day (RN-06-026, RN-11-022)" do
      Holiday.create!(level: "state", state: "RS", date: Date.new(2027, 9, 20), name: "Revolução Farroupilha")
      Holiday.create!(level: "state", state: "SC", date: Date.new(2027, 8, 11), name: "Data de SC")
      Holiday.create!(level: "city", state: "RS", ibge_city_code: "4305108", city_name: "Caxias do Sul", date: Date.new(2027, 6, 1),
        name: "Aniversário de Caxias")
      branch = unit(state: "RS", ibge_city_code: "4305108")
      unit_day(branch, kind: "holiday", date: Date.new(2027, 7, 1), name: "Festa da fábrica")
      unit_day(branch, kind: "optional_day", date: Date.new(2027, 7, 2), name: "Véspera")

      calendar = calendar(branch)
      expect([ Date.new(2027, 9, 20), Date.new(2027, 6, 1), Date.new(2027, 7, 1) ].map { |day| calendar.holiday?(day) }).to all(be(true))
      expect(calendar.holiday?(Date.new(2027, 8, 11))).to be(false)
      expect(calendar.holiday?(Date.new(2027, 7, 2))).to be(false)
      expect(calendar(unit(state: "RS")).holiday?(Date.new(2027, 6, 1))).to be(false)
    end

    it "leaves out Good Friday where the HR turned it off, only while the team allows it (D-638)" do
      branch = unit(state: "RS")
      good_friday = Holiday.find_by!(name: "Sexta-feira Santa")
      unit_day(branch, kind: "opt_out", holiday: good_friday)

      expect(calendar(branch).holiday?(Date.new(2027, 3, 26))).to be(false)
      expect(calendar.holiday?(Date.new(2027, 3, 26))).to be(true)

      good_friday.update!(unit_opt_out: false)
      expect(calendar(branch).holiday?(Date.new(2027, 3, 26))).to be(true)
    end

    it "refuses turning off a holiday the team does not allow" do
      branch = unit
      day = UnitHoliday.new(unit: branch, created_by: author, kind: "opt_out", holiday: Holiday.find_by!(name: "Proclamação da República"))

      expect(day).not_to be_valid
      expect(day.errors[:holiday]).to eq([ "não pode ser desmarcado na unidade" ])
    end

    it "lists the unit's year in date order, with what was turned off" do
      branch = unit(state: "RS")
      unit_day(branch, kind: "opt_out", holiday: Holiday.find_by!(name: "Sexta-feira Santa"))
      unit_day(branch, kind: "optional_day", date: Date.new(2027, 11, 19), name: "Ponte")

      entries = described_class.new(branch).entries(2027)

      expect(entries.map { |entry| [ entry.date.to_s, entry.name, entry.origin, entry.kind, entry.opted_out ] }).to eq([
        [ "2027-03-26", "Sexta-feira Santa", "national", "holiday", true ],
        [ "2027-11-15", "Proclamação da República", "national", "holiday", false ],
        [ "2027-11-19", "Ponte", "unit", "optional_day", false ],
        [ "2027-11-20", "Dia da consciência negra", "national", "holiday", false ]
      ])
    end
  end
end

require "rails_helper"

# Spec 04, RN-04-031 and P-04-13: the official CBO table (db/data/README.md).
RSpec.describe CboOccupation do
  def write_table(content)
    Tempfile.create([ "cbo", ".csv" ]) do |file|
      file.write(content)
      file.flush
      yield file.path
    end
  end

  it "reads the official file, with every code of 6 digits" do
    rows = described_class.rows_from

    expect(rows.size).to eq(2725)
    expect(rows).to all(match(code: /\A\d{6}\z/, title: be_present))
    expect(rows).to include(code: "252405", title: "Analista de recursos humanos")
  end

  it "loads new codes, updates titles and inactivates the ones that left, without deleting them" do
    described_class.create!(code: "111111", title: "Ocupação extinta")
    described_class.create!(code: "252405", title: "Título antigo")

    write_table("CODIGO;TITULO\n252405;Analista de recursos humanos\n252410;Analista de cargos e salários\n") do |path|
      expect(described_class.import!(path)).to eq(2)
    end

    expect(described_class.find_by(code: "252405").title).to eq("Analista de recursos humanos")
    expect(described_class.find_by(code: "252410")).to be_active
    expect(described_class.find_by(code: "111111")).not_to be_active
  end

  it "stops at a line out of the official format" do
    write_table("CODIGO;TITULO\n\"252405\";\"Analista\"\n") do |path|
      expect { described_class.import!(path) }.to raise_error(ArgumentError, /fora do formato/)
    end
  end

  it "searches by the code's start or part of the title, only active codes" do
    described_class.create!(code: "252405", title: "Analista de recursos humanos")
    described_class.create!(code: "252410", title: "Analista de cargos", active: false)

    expect(described_class.search("2524").map(&:code)).to eq([ "252405" ])
    expect(described_class.search("recursos").map(&:code)).to eq([ "252405" ])
    expect(described_class.search("a")).to be_empty
  end
end

require "rails_helper"
require "open3"

# Spec 18, block 18e (RN-18-070 to RN-18-075, CA-18-011, D-667): the company's full export
# made by the job, opened with the 7-Zip of the container as the HR would open it.
RSpec.describe "The company's full export" do
  include ActiveJob::TestHelper

  let(:company) { create(:company, name: "Metalúrgica Serra Azul") }
  let(:hr_user) { create(:user, name: "Juliana Ribeiro") }
  let!(:hr) { create(:membership, user: hr_user, organization: company, roles: %w[hr_admin]) }
  let(:position) { create_position(company) }
  let(:profile) { register_employee(company, by: hr_user, position: position, name: "Marcos Teles", cpf: "52998224725") }

  around { |example| ActsAsTenant.with_tenant(company) { example.run } }

  before do
    travel_to Time.zone.local(2026, 11, 10, 10)
    load_platform_document_types
  end

  after { travel_back }

  def pdf(content = "%PDF-1.4\n%fake\n")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: "rg.pdf")
  end

  def reviewed(code, content = "%PDF-1.4\n%fake\n")
    form = Documents::Upload.new(worker_profile: profile, document_type: DocumentType.find_by!(code: code), files: [ pdf(content) ], by: hr_user)
    form.save
    form.version.files.blobs.each { |blob| blob.file_scan.record!(Antivirus::Clamd::Result.new(signature: nil)) }
    perform_enqueued_jobs(only: Documents::ConsolidatePdfJob)
    Documents::Review.new(form.version.reload, by: hr_user).approve
    form.document.reload
  end

  # Extracts the parts with the password into a folder and yields it.
  def extract(export, password)
    Dir.mktmpdir do |dir|
      paths = export.ordered_parts.map do |part|
        File.join(dir, part.filename.to_s).tap { |path| File.binwrite(path, part.download) }
      end
      out_dir = File.join(dir, "out")
      _out, err, status = Open3.capture3("7z", "x", "-p#{password}", "-o#{out_dir}", paths.first)
      raise "7z failed: #{err}" unless status.success?

      yield out_dir, paths
    end
  end

  def zip_method(path)
    out, _err, _status = Open3.capture3("7z", "l", "-slt", "-pqualquer", path)
    out[/^Method = (.+)$/, 1]
  end

  it "has LEIAME.txt, indice.json with the hashes, the data in JSON and CSV and the files, with the password (CA-18-011)" do
    profile.update!(rg_number: "123456789", rg_issuer: "SSP")
    BankAccount.create!(worker_profile: profile, bank_code: "001", branch: "1234", account_number: "98765-4", account_type: "checking",
      primary: true, status: "active", declared_by: hr_user, declared_at: Time.current)
    reviewed("rg", "%PDF-1.4\n%primeira\n")
    other_company = create(:company, name: "Padaria Pão Quente")
    ActsAsTenant.with_tenant(other_company) { create_position(other_company, name: "Padeiro") }

    export = CompanyExport.create!(requested_by: hr_user)
    Exports::CompanyJob.perform_now(export)
    export.reload
    expect(export).to have_attributes(status: "ready", files_count: 1)
    expect(export.expires_at).to be_within(1.minute).of(7.days.from_now)
    expect(export.ordered_parts.map { |part| part.filename.to_s }).to eq([ "catalysthr-export-metalurgica-serra-azul-20261110.zip" ])
    expect(export.parts.blobs.map(&:key)).to all(start_with("companies/#{company.id}/exports/"))
    expect(export.password).to match(/\A[A-Za-z2-9]{24}\z/)

    password = export.password
    extract(export, password) do |dir, paths|
      expect(zip_method(paths.first)).to include("AES-256")
      _out, _err, wrong = Open3.capture3("7z", "t", "-perrada", paths.first)
      expect(wrong).not_to be_success

      expect(File.read(File.join(dir, "LEIAME.txt"))).to include("Metalúrgica Serra Azul", "Versão do formato: 1", "fichas:", "dados/csv/<tabela>.csv")
      index = JSON.parse(File.read(File.join(dir, "indice.json")))
      expect(index).to include("formato" => "1", "quantidade_de_arquivos" => 1)

      people = index["entidades"].find { |entity| entity["nome"] == "fichas" }
      expect(people["registros"]).to eq(1)
      expect(Digest::SHA256.file(File.join(dir, people["json"]["caminho"])).hexdigest).to eq(people["json"]["sha256"])
      expect(Digest::SHA256.file(File.join(dir, people["csv"]["caminho"])).hexdigest).to eq(people["csv"]["sha256"])

      file = index["arquivos"].sole
      expect(file["caminho"]).to eq("arquivos/52998224725/Pessoais/RG-v1.pdf")
      expect(File.binread(File.join(dir, file["caminho"]))).to include("%primeira")
      expect(Digest::SHA256.file(File.join(dir, file["caminho"])).hexdigest).to eq(file["sha256"])

      # The encrypted fields leave readable (RN-18-075).
      fichas = JSON.parse(File.read(File.join(dir, "dados/json/fichas.json")))
      expect(fichas.sole).to include("rg_number" => "123456789", "rg_issuer" => "SSP")
      expect(JSON.parse(File.read(File.join(dir, "dados/json/contas_bancarias.json"))).sole).to include("account_number" => "987654")
      csv = File.read(File.join(dir, "dados/csv/fichas.csv"), encoding: "bom|utf-8")
      expect(csv.lines.first).to start_with("id;company_id;")
      expect(File.binread(File.join(dir, "dados/csv/fichas.csv"))).to start_with("\xEF\xBB\xBF".b)

      # No secret and no other company (RN-18-072, spec 01).
      users = JSON.parse(File.read(File.join(dir, "dados/json/usuarios.json")))
      expect(users.map { |user| user["name"] }).to contain_exactly("Juliana Ribeiro", "Marcos Teles")
      expect(users.flat_map(&:keys).uniq).to contain_exactly(*%w[id name cpf email mobile_phone birth_date status created_at updated_at])
      all = Dir.glob(File.join(dir, "dados/json/*.json")).map { |path| File.read(path) }.join
      expect(all).not_to include("encrypted_password", "otp_secret", "invitation_token_digest", "Padaria Pão Quente", "Padeiro")
      expect(Dir.children(File.join(dir, "dados/json"))).not_to include("faturas.json", "notificacoes.json")
    end
  end

  it "leaves the deleted documents out, which wait for their recovery (RN-08-083)" do
    reviewed("rg")
    document = reviewed("aso_periodic")
    Documents::Removal.new(document, by: hr_user).delete(reason: "Errado")

    export = CompanyExport.create!(requested_by: hr_user)
    Exports::CompanyJob.perform_now(export)
    extract(export.reload, export.password) do |dir, _paths|
      index = JSON.parse(File.read(File.join(dir, "indice.json")))
      expect(index["arquivos"].map { |file| file["caminho"] }).to eq([ "arquivos/52998224725/Pessoais/RG-v1.pdf" ])
      expect(JSON.parse(File.read(File.join(dir, "dados/json/documentos.json"))).map { |row| row["id"] }).not_to include(document.id)
    end
  end

  it "tells who asked once it is ready, without the password (RN-18-073, RN-15-005)" do
    export = CompanyExport.create!(requested_by: hr_user)
    Exports::CompanyJob.perform_now(export)
    Exports::CompanyJob.perform_now(export)

    notification = Notification.where(notification_type: "exports.company_ready", recipient_user: hr_user).sole
    expect(notification).to have_attributes(path: "/data-exports/#{export.id}", mandatory: true)
    expect("#{notification.title} #{notification.body}").not_to include(export.reload.password)
    expect(notification.body).to include("17/11/2026")
  end

  it "fails after the last try with nothing left in the storage, and does not count for the week (RN-18-074)" do
    export = CompanyExport.create!(requested_by: hr_user)
    allow(Exports::SevenZip).to receive(:encrypt!).and_raise(Exports::SevenZip::Failed, "disco cheio")
    allow(Sentry).to receive(:capture_exception)

    perform_enqueued_jobs { Exports::CompanyJob.perform_later(export) }
    expect(export.reload).to have_attributes(status: "failed", password: nil)
    expect(export.parts).not_to be_attached
    expect(Sentry).to have_received(:capture_exception).once
    expect(CompanyExport.next_allowed_at).to be_nil
  end

  it "leaves the parts and the password after 7 days, keeping the record (RN-18-073)" do
    export = CompanyExport.create!(requested_by: hr_user)
    Exports::CompanyJob.perform_now(export)

    travel_to(6.days.from_now) { Exports::PurgeJob.perform_now }
    expect(export.reload).to be_ready
    travel_to(8.days.from_now) { Exports::PurgeJob.perform_now }
    expect(export.reload).to have_attributes(status: "expired", password: nil)
    expect(export.parts).not_to be_attached
  end

  it "splits a large export in 7-Zip volumes that open together with the password (RN-18-073, D-667)" do
    Dir.mktmpdir do |dir|
      root = File.join(dir, "conteudo")
      FileUtils.mkdir_p(root)
      File.binwrite(File.join(root, "grande.bin"), Random.new(1).bytes(300_000))
      parts = Exports::SevenZip.encrypt!(dir: root, entries: [ "grande.bin" ], zip_path: File.join(dir, "x.zip"), password: "SenhaDeTeste23",
        volume_size: 100_000)
      expect(parts.map { |path| File.basename(path) }).to eq(%w[x.zip.001 x.zip.002 x.zip.003 x.zip.004])
      out, _err, status = Open3.capture3("7z", "x", "-pSenhaDeTeste23", "-o#{dir}/out", parts.first)
      expect(status).to be_success, out
      expect(File.size(File.join(dir, "out", "grande.bin"))).to eq(300_000)
    end
  end

  it "kills a 7-Zip that stops answering, so it never holds the queue" do
    allow(PTY).to receive(:spawn).and_wrap_original { |original, *_args, **options, &block| original.call("sleep", "30", **options, &block) }
    Dir.mktmpdir do |dir|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect do
        Exports::SevenZip.encrypt!(dir: dir, entries: [ "a.txt" ], zip_path: File.join(dir, "a.zip"), password: "x", volume_size: 1_000, time_limit: 0.5)
      end.to raise_error(Exports::SevenZip::Failed, /stopped answering/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
    end
  end

  it "never puts the password on the command line (P-20-07)" do
    spawned = []
    allow(PTY).to receive(:spawn).and_wrap_original { |original, *args, **options, &block| spawned << args; original.call(*args, **options, &block) }
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.txt"), "oi")
      Exports::SevenZip.encrypt!(dir: dir, entries: [ "a.txt" ], zip_path: File.join(dir, "a.zip"), password: "NaoAparece99", volume_size: 1_000_000)
    end
    expect(spawned.flatten.join(" ")).not_to include("NaoAparece99")
    expect(spawned.flatten).to include("-p")
  end
end

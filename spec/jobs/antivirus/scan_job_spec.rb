require "rails_helper"

# Spec 05 (P-05-30) and spec 20 (RN-20-015, CA-20-005), D-640: each upload is scanned
# before being served; ClamAV is simulated.
RSpec.describe Antivirus::ScanJob do
  let(:blob) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4 manual"), filename: "manual.pdf", content_type: "application/pdf") }
  let!(:scan) { FileScan.create!(blob: blob) }
  let(:client) { instance_double(Antivirus::Clamd) }

  before { allow(Antivirus::Clamd).to receive(:new).and_return(client) }

  it "is enqueued when a file starts scanning" do
    expect(described_class).to have_been_enqueued.with(scan)
  end

  it "releases a clean file" do
    allow(client).to receive(:scan).and_return(Antivirus::Clamd::Result.new(signature: nil))

    described_class.perform_now(scan)

    expect(scan.reload).to have_attributes(status: "clean", signature: nil)
    expect(scan.scanned_at).to be_present
  end

  it "deletes an infected file from the storage, keeping the blob and the signature only" do
    allow(client).to receive(:scan).and_return(Antivirus::Clamd::Result.new(signature: "Eicar-Test-Signature"))
    allow(Sentry).to receive(:capture_message)

    described_class.perform_now(scan)

    expect(scan.reload).to have_attributes(status: "infected", signature: "Eicar-Test-Signature")
    expect(blob.service.exist?(blob.key)).to be(false)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    expect(Sentry).to have_received(:capture_message).with("Virus found in an upload", level: :warning,
      extra: { signature: "Eicar-Test-Signature" })
  end

  it "keeps the file in scanning and tries again with ClamAV out of reach (CA-20-005)" do
    allow(client).to receive(:scan).and_raise(Antivirus::Clamd::Unavailable)

    expect { described_class.perform_now(scan) }.to have_enqueued_job(described_class)
    expect(scan.reload).to be_scanning
    expect(scan.attempted_at).to be_present
  end

  it "leaves alone a file already scanned" do
    scan.update!(status: "clean")

    described_class.perform_now(scan)

    expect(Antivirus::Clamd).not_to have_received(:new)
  end
end

RSpec.describe Antivirus::RescanPendingJob do
  def scan_at(created, attempted: nil, status: "scanning")
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF"), filename: "a.pdf", content_type: "application/pdf")
    FileScan.create!(blob: blob, status: status, created_at: created, attempted_at: attempted)
  end

  it "sends back what is still scanning an hour after the last attempt" do
    stale = scan_at(3.hours.ago, attempted: 2.hours.ago)
    never = scan_at(2.hours.ago)
    scan_at(3.hours.ago, attempted: 10.minutes.ago)
    scan_at(5.minutes.ago)
    scan_at(3.hours.ago, status: "clean")
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    expect { described_class.perform_now }.to have_enqueued_job(Antivirus::ScanJob).exactly(2).times
    expect(Antivirus::ScanJob).to have_been_enqueued.with(stale)
    expect(Antivirus::ScanJob).to have_been_enqueued.with(never)
  end
end

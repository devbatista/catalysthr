require "rails_helper"

# Spec 02, RN-02-084 and RN-02-085 (D-186): during a simulated write nothing is saved
# and nothing leaves the system.
RSpec.describe Simulation do
  include ActiveJob::TestHelper

  it "undoes the writes" do
    described_class.run { create(:company) }

    expect(Company.count).to eq(0)
    expect(described_class).not_to be_active
  end

  it "does not enqueue jobs, including e-mails sent later" do
    membership = create(:membership)

    described_class.run do
      Invitations::DeliverJob.perform_later(membership, "token")
      AccountMailer.contact_changed(membership.user, "old@example.com", membership).deliver_later
    end

    expect(enqueued_jobs).to be_empty
  end

  it "does not deliver e-mails sent right away" do
    membership = create(:membership)

    described_class.run { AccountMailer.contact_changed(membership.user, "old@example.com", membership).deliver_now }

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "refuses HTTP calls, which covers S3 and the external services" do
    # WebMock answers before Net::HTTP itself; without it, the guard is what remains.
    WebMock.disable!
    expect { described_class.run { Net::HTTP.get(URI("https://example.com/")) } }
      .to raise_error(Simulation::ExternalCallBlocked)
  ensure
    WebMock.enable!
  end
end

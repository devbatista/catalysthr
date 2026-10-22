require "rails_helper"

# Spec 20, block 20a (RN-20-046, D-627): the quarterly reminder of the restore drill.
RSpec.describe Infra::RestoreDrillReminderJob do
  let!(:superadmin) { create(:user, platform_role: "superadmin") }

  before { create(:user, platform_role: "finance") }

  around { |example| travel_to(Time.zone.local(2027, 1, 1, 9)) { example.run } }

  it "tells the superadmins once a quarter, with the last drill" do
    BackupRun.create!(kind: "restore_drill", status: "succeeded", started_at: Time.zone.local(2026, 10, 5, 10))

    2.times { described_class.perform_now }

    notice = Notification.sole
    expect(notice).to have_attributes(recipient_user: superadmin, notification_type: "platform.restore_drill_due", area: "admin",
      title: "Hora do ensaio de restauração do backup")
    expect(notice.body).to include("05/10/2026", "docs/runbooks/restauracao.md")
  end

  it "says when no drill was recorded" do
    described_class.perform_now

    expect(Notification.sole.body).to start_with("Nenhum ensaio foi registrado ainda.")
  end
end

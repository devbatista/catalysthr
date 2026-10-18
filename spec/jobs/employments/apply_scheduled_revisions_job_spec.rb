require "rails_helper"

# Spec 04, P-04-29, and spec 15, `employments.revisions_effective` (D-602, D-608): one
# notice a day for each HR person, with the revisions of their scope, names and reasons only.
RSpec.describe Employments::ApplyScheduledRevisionsJob do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:hr_admin) { create(:membership, organization: company, roles: %w[hr_admin]).user }
  let(:position) { create_position(company) }
  let(:branch) { ActsAsTenant.with_tenant(company) { Unit.create!(name: "Filial") } }
  let!(:analyst) do
    create(:membership, organization: company, roles: %w[hr_analyst]).tap do |membership|
      Memberships::AssignUnits.call(membership: membership, unit_ids: [ branch.id ], by: hr_admin)
    end
  end
  let(:today) { Date.new(2026, 12, 1) }

  around { |example| travel_to(Time.zone.local(2026, 10, 17, 10)) { example.run } }

  def revise(profile, reason: "salary_change", **attributes)
    ActsAsTenant.with_tenant(company) do
      employment = profile.employments.sole
      current = employment.current_revision
      employment.revisions.create!(effective_on: today, reason: reason, position: current.position, unit: current.unit,
        salary_cents: 999_999, salary_unit: current.salary_unit, created_by: hr_admin, justification: "Acordo", **attributes)
    end
  end

  def notices(membership)
    Notification.where(recipient_membership: membership, notification_type: "employments.revisions_effective")
  end

  it "tells the administrator everything and the analyst only the revisions in their units, once a day" do
    ana = register_employee(company, by: hr_admin, position: position, name: "Ana Lima")
    bruno = register_employee(company, by: hr_admin, position: position, name: "Bruno Reis")
    revise(ana)
    revise(bruno, reason: "transfer", unit: branch)
    admin_membership = Membership.find_by!(user: hr_admin, organization: company)

    perform_enqueued_jobs { 2.times { described_class.perform_now(today) } }

    admin_notice = notices(admin_membership).sole
    expect(admin_notice).to have_attributes(title: "2 revisões entram em vigor hoje", path: "/employees",
      body: "Ana Lima (alteração salarial) e Bruno Reis (transferência).")
    expect(notices(analyst).sole).to have_attributes(title: "1 revisão entra em vigor hoje", path: "/employees/#{bruno.id}",
      body: "Bruno Reis (transferência).")
    expect(ActionMailer::Base.deliveries.map(&:subject)).to contain_exactly("2 revisões entram em vigor hoje",
      "1 revisão entra em vigor hoje")
    expect(ActionMailer::Base.deliveries.map { |mail| mail.text_part.body.to_s }.join).not_to include("9.999", "999999")
  end

  it "leaves the admission out and says nothing on a day without revisions" do
    register_employee(company, by: hr_admin, position: position, started_on: Date.new(2026, 3, 1))

    described_class.perform_now(Date.new(2026, 3, 1))
    described_class.perform_now(today)

    expect(Notification.count).to eq(0)
  end

  it "counts the people beyond the first three" do
    profiles = %w[Ana Bruno Carla Davi].map { |name| register_employee(company, by: hr_admin, position: position, name: name) }
    profiles.each { |profile| revise(profile) }

    described_class.perform_now(today)

    expect(Notification.find_by!(recipient_user: hr_admin).body).to end_with("Carla (alteração salarial) e mais 1.")
  end
end

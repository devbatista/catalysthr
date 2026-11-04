# What a manager follows of the team in the portal (spec 16, RN-16-030, D-420, D-645): the
# process items assigned to them, and the team's documents expiring, the text only and
# never the file (P-08-11). Approvals, absences, the schedule and the probation's end come
# with specs 09, 10, 11 and 07.
class TeamOverview
  Expiring = Data.define(:document, :person, :date, :status)

  def initialize(membership)
    @membership = membership
  end

  def items
    @items ||= ProcessItem.where("? = ANY(responsible_membership_ids)", @membership.id).where(status: "pending")
      .joins(:instance).merge(ProcessInstance.open).includes(instance: { subject: { worker_profile: :user } }).order(:due_on).to_a
  end

  def expiring
    @expiring ||= begin
      team = WorkerProfile.in_departments(Department.team_ids_for(@membership)).select(:id)
      Document.kept.where(worker_profile_id: team, status: %w[expiring expired]).includes(:document_type, worker_profile: :user)
        .order(:expires_on).limit(50).map do |document|
          Expiring.new(document.document_type.name, document.worker_profile.display_name, document.expires_on, document.status)
        end
    end
  end

  def empty?
    items.empty? && expiring.empty?
  end
end

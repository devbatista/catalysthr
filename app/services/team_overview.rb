# What a manager follows of the team (spec 16, RN-16-030, D-420, D-645), in the portal's
# "Minha equipe" and in the manager's panel, which show the same (spec 17, RN-17-020,
# RN-17-021, D-659): the people of the team, the process items assigned to them, the team's
# documents expiring, the text only and never the file (P-08-11), and the experiences about
# to end, without an action (RN-07-101, D-653). Approvals, absences and the schedule come
# with specs 09, 10 and 11. The panel may narrow it to one unit of the team (RN-17-004).
class TeamOverview
  Expiring = Data.define(:document, :person, :date, :status)
  Probation = Data.define(:person, :date)
  Member = Data.define(:profile, :employment, :revision) do
    def on_leave? = employment.on_leave?
  end

  attr_reader :unit_id

  def initialize(membership, unit_id: nil)
    @membership = membership
    # A unit outside the team is ignored. Without a filter, the units are not even read.
    @unit_id = unit_id.presence && unit_id.to_s.presence_in(units.map { |unit| unit.id.to_s })
  end

  # The units of the team's people, for the panel's filter.
  def units
    @units ||= Unit.where(id: EmploymentRevision.counting.where(employment_id: Employment.where(worker_profile_id: all_team).select(:id))
      .select(:unit_id)).ordered.to_a
  end

  # The people of the team, active and on leave (RN-17-020), by name.
  def members
    @members ||= Employment.where(worker_profile_id: team, status: %w[active on_leave])
      .includes(worker_profile: :user, revisions: %i[position department unit]).to_a
      .map { |employment| Member.new(employment.worker_profile, employment, employment.effective_revision) }
      .sort_by { |member| I18n.transliterate(member.profile.display_name).downcase }
  end

  def items
    @items ||= begin
      items = ProcessItem.where("? = ANY(responsible_membership_ids)", @membership.id).where(status: "pending")
        .joins(:instance).merge(ProcessInstance.open)
      items = items.where(process_instances: { unit_id: unit_id }) if unit_id
      items.includes(instance: { subject: { worker_profile: :user } }).order(:due_on).to_a
    end
  end

  def expiring
    @expiring ||= Document.kept.where(worker_profile_id: team, status: %w[expiring expired]).includes(:document_type, worker_profile: :user)
      .order(:expires_on).limit(50).map do |document|
        Expiring.new(document.document_type.name, document.worker_profile.display_name, document.expires_on, document.status)
      end
  end

  def probations
    @probations ||= begin
      lead = Current.company.experience_alert_days
      Employment.with_experience_open(Employment.where(worker_profile_id: team)).includes(worker_profile: :user).to_a
        .select { |employment| employment.experience_ends_on <= Date.current + lead }.sort_by(&:experience_ends_on)
        .map { |employment| Probation.new(employment.worker_profile.display_name, employment.experience_ends_on) }
    end
  end

  def empty?
    items.empty? && expiring.empty? && probations.empty?
  end

  private

  def all_team
    WorkerProfile.in_departments(Department.team_ids_for(@membership)).select(:id)
  end

  def team
    unit_id ? WorkerProfile.where(id: all_team).where(id: WorkerProfile.in_units(unit_id).select(:id)).select(:id) : all_team
  end
end

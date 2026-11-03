# The people's choice of a document request and of a publication (RN-08-040, RN-08-050,
# D-643): one person, or a group by structure and the dependents' criteria.
module DocumentAudienceForm
  extend ActiveSupport::Concern

  included do
    helper_method :audience_people, :audience_options, :audience_types
  end

  private

  def audience_params
    params.fetch(:audience, {}).permit(*Documents::Audience::FLAGS, Documents::Audience::LISTS.to_h { |key| [ key, [] ] })
  end

  # The people who may get it, for the single person's choice.
  def audience_people
    @audience_people ||= WorkerProfile.accessible_by(current_ability, :read).where(id: Employment.open.select(:worker_profile_id))
      .includes(:user).sort_by(&:display_name)
  end

  def audience_options
    {
      "unit_ids" => Unit.active.ordered.map { |unit| [ unit.name, unit.id ] },
      "department_ids" => Department.active.includes(:unit).ordered.map { |department| [ "#{department.name} (#{department.unit.name})", department.id ] },
      "position_ids" => Position.active.ordered.map { |position| [ position.name, position.id ] },
      "employment_kinds" => Employment::KINDS.map { |kind| [ I18n.t("employments.kinds.#{kind}"), kind ] }
    }
  end

  # The types of the categories the person sends; each person of the group is checked
  # again by Documents::Audience.
  def audience_types
    categories = DocumentCategory.readable(health: true, pay: can?(:read_pay, WorkerProfile))
    DocumentType.usable.ordered.select { |type| categories.include?(type.category) }
  end

  # Only the people of the viewer's scope, on a panel shared by the HR (RN-03-006).
  def visible_profile_ids
    WorkerProfile.accessible_by(current_ability, :read).select(:id)
  end
end

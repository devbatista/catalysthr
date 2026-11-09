# An area of a unit, in a tree within the unit, with zero or more managers (RN-04-020 to
# RN-04-025, D-202, D-203). A manager's team is the people of the departments they manage
# and of their subdepartments (RN-04-022, D-190): the E scope.
class Department < ApplicationRecord
  audited

  STATUSES = %w[active inactive].freeze

  acts_as_tenant :company
  include StructureCode

  belongs_to :unit
  belongs_to :parent, class_name: "Department", optional: true
  has_many :children, class_name: "Department", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :department_managers, dependent: :destroy
  has_many :managers, through: :department_managers, source: :membership

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :ordered, -> { order(:name) }

  validates :name, presence: true, length: { maximum: 120 }
  validate :parent_in_same_unit
  validate :no_cycle
  validate :empty_before_inactive, if: -> { status_changed? && inactive? }

  def audit_company_id
    company_id
  end

  # The department and every department below it (RN-04-022, P-04-10).
  def self.subtree_ids(ids)
    ids = Array(ids)
    return [] if ids.empty?

    sql = <<~SQL.squish
      WITH RECURSIVE tree AS (
        SELECT id FROM departments WHERE id IN (:ids) AND company_id = :company_id
        UNION
        SELECT departments.id FROM departments JOIN tree ON departments.parent_id = tree.id
        WHERE departments.company_id = :company_id
      )
      SELECT id FROM tree
    SQL
    connection.select_values(sanitize_sql([ sql, { ids: ids, company_id: ActsAsTenant.current_tenant.id } ]))
  end

  # The departments a manager's membership manages, with their subdepartments: the E
  # scope (D-190).
  def self.team_ids_for(membership)
    subtree_ids(DepartmentManager.where(membership: membership).select(:department_id).map(&:department_id))
  end

  # From the parent up to the root. Stops at a repeated department, so a cycle being
  # validated never loops.
  def ancestors
    list = []
    node = parent
    while node && list.exclude?(node) && node != self
      list << node
      node = node.parent
    end
    list
  end

  # Who approves for someone of this department who is also its manager: the managers of
  # the nearest ancestor with any, or none, when the approval goes to the HR (RN-04-024,
  # P-04-11, CA-04-003).
  def managers_above
    ancestors.each do |ancestor|
      managers = ancestor.managers.to_a
      return managers if managers.any?
    end
    []
  end

  private

  def parent_in_same_unit
    errors.add(:parent, :other_unit) if parent && parent.unit_id != unit_id
  end

  def no_cycle
    return if parent_id.nil? || new_record?

    errors.add(:parent, :cycle) if self.class.subtree_ids(id).include?(parent_id)
  end

  # Only an empty department is inactivated: no active subdepartment and no open
  # employment in it, now or later (RN-04-025, P-04-12).
  def empty_before_inactive
    errors.add(:status, :active_children) if children.active.exists?
    errors.add(:status, :open_employments) if EmploymentRevision.placing_open_employments.exists?(department_id: id)
  end
end

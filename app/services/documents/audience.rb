module Documents
  # The people of a request or a publication (RN-08-040, RN-08-050, D-643): one person, or
  # a group by unit, department, position and employment kind, and those with a dependent
  # for family allowance or for IRRF. Only people with an open employment, inside the
  # scope of who asks and with a folder they may send this type to. The filter is kept as
  # it came, in audience_filter.
  class Audience
    LISTS = %w[worker_profile_ids unit_ids department_ids position_ids employment_kinds].freeze
    FLAGS = %w[family_allowance irrf].freeze

    attr_reader :filter

    def initialize(filter, ability:, document_type:)
      filter = filter.to_h.stringify_keys
      @filter = LISTS.to_h { |key| [ key, Array(filter[key]).map(&:to_s).compact_blank.uniq ] }.select { |_key, values| values.any? }
        .merge(FLAGS.to_h { |key| [ key, ActiveModel::Type::Boolean.new.cast(filter[key]) || false ] }.select { |_key, value| value })
      @ability = ability
      @document_type = document_type
    end

    def empty?
      filter.empty?
    end

    def profiles
      return WorkerProfile.none if empty? || @document_type.nil?

      scope = WorkerProfile.accessible_by(@ability, :read).where(id: Employment.open.select(:worker_profile_id))
      scope = scope.where(id: filter["worker_profile_ids"]) if filter["worker_profile_ids"]
      scope = scope.in_units(filter["unit_ids"]) if filter["unit_ids"]
      scope = scope.in_departments(filter["department_ids"]) if filter["department_ids"]
      scope = scope.where(id: people_in(EmploymentRevision.counting.where(position_id: filter["position_ids"]))) if filter["position_ids"]
      scope = scope.where(id: Employment.open.where(kind: filter["employment_kinds"]).select(:worker_profile_id)) if filter["employment_kinds"]
      FLAGS.each { |flag| scope = scope.where(id: Dependent.active.where(flag => true).select(:worker_profile_id)) if filter[flag] }
      scope.includes(:user, employments: { revisions: :unit }).to_a.select { |profile| sendable?(profile) }
    end

    private

    def people_in(revisions)
      Employment.open.where(id: revisions.select(:employment_id)).select(:worker_profile_id)
    end

    def sendable?(profile)
      @ability.can?(:upload, Document.new(worker_profile: profile, company: profile.company, document_type: @document_type))
    end
  end
end

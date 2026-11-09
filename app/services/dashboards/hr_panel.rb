module Dashboards
  # The HR panel's numbers (spec 17, section 4.2, D-657, D-658), always in the person's scope
  # (RN-17-001) and with the panel's filter (RN-17-004, RN-17-005). Each indicator and the
  # list it opens use the same query, defined only here (RN-17-002, P-17-01). An indicator
  # whose module the person does not operate is not shown (RN-17-014), and one whose module
  # is not built yet does not exist (D-657).
  class HrPanel
    EXPIRATION_DAYS = 30
    UPCOMING_SHOWN = 10
    DEFAULT_TIME_ZONE = "America/Sao_Paulo".freeze

    attr_reader :filter

    delegate :ability, :today, to: :filter

    def initialize(filter)
      @filter = filter
    end

    # Admissions in progress (RN-17-010): not concluded nor cancelled.
    def admissions?
      FeatureFlags.enabled?(FeatureFlags::ADMISSIONS) && ability.can?(:read, Admission)
    end

    def admissions
      reachable = Admission.where(id: Admission.accessible_by(ability, :read).select(:id))
      filter_admissions(reachable).in_status("open")
    end

    # The admissions given, with the panel's filter: the admissions list uses it too.
    def filter_admissions(relation)
      relation = relation.joins(:process_instance)
      relation = filter.instances(relation)
      relation
    end

    # Of those, the ones with a correction asked to the person.
    def admissions_with_correction
      admissions.where(process_instance_id: ProcessItem.correction_requested.select(:process_instance_id))
    end

    # Pending documents (RN-17-010, D-658): versions waiting for the review, plus the people
    # of a request without any version sent yet (the ones with a version are in review).
    def documents?
      ability.can?(:review, Document)
    end

    def versions_in_review
      reachable = Document.kept.accessible_by(ability, :review)
      DocumentVersion.where(status: DocumentVersion::REVIEWABLE)
        .where(document_id: reachable.where(worker_profile_id: filter.people.select(:id)).select(:id))
    end

    def unanswered_requests
      reachable = Document.kept.accessible_by(ability, :review)
      DocumentRequestTarget.pending.where(document_id: reachable.select(:id), worker_profile_id: filter.people.select(:id))
    end

    # Requests past their date, in the support line.
    def late_requests
      unanswered_requests.joins(:request).where(document_requests: { due_on: ...today })
    end

    def pending_documents_count
      versions_in_review.count + unanswered_requests.count
    end

    # Overdue items of processes (RN-06-028, D-658): open, with the date passed in the unit's
    # time zone, of open processes the person runs.
    def overdue_items?
      ability.can?(:adjust, ProcessInstance)
    end

    def overdue_items
      filter.instances(self.class.overdue(ProcessItem.where(id: ProcessItem.accessible_by(ability, :act).select(:id))))
    end

    # The open items of open processes past their date in the unit's time zone (RN-06-028), as
    # ProcessItem#overdue? says, in one query. The partner's view counts them too (D-660).
    def self.overdue(items)
      items.where(status: ProcessItem::OPEN).where.not(due_on: nil)
        .joins(:instance).where(process_instances: { status: "open" })
        .joins("LEFT JOIN units item_units ON item_units.id = process_instances.unit_id")
        .where("process_items.due_on < (now() AT TIME ZONE COALESCE(item_units.time_zone, '#{DEFAULT_TIME_ZONE}'))::date")
    end

    # The unit with the most overdue items, for the support line.
    def overdue_top_unit
      unit_id, count = overdue_items.group("process_instances.unit_id").count.max_by { |id, total| [ total, id.to_s ] }
      unit_id && [ filter.units.find { |unit| unit.id == unit_id } || Unit.find_by(id: unit_id), count ]
    end

    # Expirations in 30 days (RN-17-010, D-658): documents with validity and experience
    # periods ending from today on, never the expired ones. The A1 certificate comes with
    # spec 13 (D-657).
    def expirations?
      documents? || ability.can?(:read, WorkerProfile)
    end

    def expiring_documents
      return Document.none unless ability.can?(:read, Document)

      Document.kept.accessible_by(ability, :read).where.not(current_version_id: nil)
        .where(expires_on: today..(today + EXPIRATION_DAYS), worker_profile_id: filter.people.select(:id))
    end

    def experience_endings
      people = filter.people(WorkerProfile.accessible_by(ability, :read))
      Employment.with_experience_open(Employment.where(worker_profile_id: people.select(:id)))
        .where("(employments.details->>'experience_ends_on')::date BETWEEN ? AND ?", today, today + EXPIRATION_DAYS)
    end

    def expirations_count
      expiring_documents.count + experience_endings.count
    end

    # Every expiration of the 30 days, the nearest first: the list and the panel's block,
    # which shows the first 10 (RN-17-011).
    def expirations(limit: nil)
      documents = expiring_documents.includes(:document_type, :dependent, worker_profile: :user).order(:expires_on, :id)
      endings = experience_endings.includes(worker_profile: :user).order(Arel.sql("(employments.details->>'experience_ends_on')::date"), :id)
      if limit
        documents = documents.limit(limit)
        endings = endings.limit(limit)
      end
      rows = documents.map { |document| Expiration.new(document.expires_on, :document, document, document.worker_profile) } +
        endings.map { |employment| Expiration.new(employment.experience_ends_on, :experience, employment, employment.worker_profile) }
      rows = rows.sort_by { |row| [ row.date, row.kind == :document ? 0 : 1, row.record.id ] }
      limit ? rows.first(limit) : rows
    end

    # The two most common kinds, for the support line.
    def expiration_kinds
      kinds = expiring_documents.joins(:document_type).group("document_types.name").count
      endings = experience_endings.count
      kinds[I18n.t("dashboards.hr.experience_end")] = endings if endings.positive?
      kinds.sort_by { |name, count| [ -count, name ] }.first(2)
    end

    Expiration = Data.define(:date, :kind, :record, :person)

    # Active employees (RN-17-010): people with an employment active or on leave, as the people
    # list counts them, which shows each person once, by the employment that represents them.
    def employees?
      ability.can?(:read, WorkerProfile)
    end

    def employee_rows
      @employee_rows ||= begin
        profiles = WorkerProfile.accessible_by(ability).includes(:user,
          employments: { revisions: [ :position, :unit, :allocation_client, { department: { managers: :user } } ] })
        EmployeeRow.filter(EmployeeRow.build(profiles), unit_id: filter.unit_id, client_id: filter.client_id, situation: "active")
      end
    end

    def employees_by_unit
      employee_rows.group_by(&:unit).transform_values(&:size).sort_by { |unit, count| [ -count, unit&.name.to_s ] }
    end

    # Pending items by unit (RN-17-011): the documents and the overdue items of each unit of
    # the scope. The approvals come with spec 09 (D-657). A person counts in each unit where the
    # U scope places them (D-142).
    def pending_by_unit
      units = filter.unit ? [ filter.unit ] : filter.units
      documents = documents? ? documents_by_unit : {}
      overdue = overdue_items? ? overdue_items.group("process_instances.unit_id").count : {}
      units.map { |unit| PendingRow.new(unit, documents.fetch(unit.id, 0), overdue.fetch(unit.id, 0)) }
    end

    PendingRow = Data.define(:unit, :documents, :overdue)

    # The recent activity (RN-17-011, P-17-03): the last 20 happenings of the scope, of the
    # modules the person operates.
    def activity
      events = ActivityEvent.where(module_code: Membership::RELEASABLE_MODULES.select { |code| ability.can?(:use_module, code.to_sym) })
      scope = ability.hr_unit_ids
      events = events.where(unit_id: scope) unless scope == :all
      events = events.where(unit_id: filter.unit_id) if filter.unit_id
      if filter.client
        events = events.where(allocation_client_id: filter.client.id)
      elsif filter.no_client?
        events = events.where(allocation_client_id: nil)
      end
      events.order(occurred_at: :desc, id: :desc).limit(ActivityEvent::SHOWN)
    end

    private

    # The people of each pending document, placed in their units.
    def documents_by_unit
      profile_ids = versions_in_review.joins(:document).pluck("documents.worker_profile_id") + unanswered_requests.pluck(:worker_profile_id)
      return {} if profile_ids.empty?

      units = EmploymentRevision.counting.joins("INNER JOIN employments ON employments.id = employment_revisions.employment_id")
        .where(employments: { worker_profile_id: profile_ids.uniq }).distinct.pluck("employments.worker_profile_id", :unit_id)
        .group_by(&:first).transform_values { |pairs| pairs.map(&:last).uniq }
      profile_ids.flat_map { |id| units.fetch(id, []) }.tally
    end
  end
end

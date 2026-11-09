module Announcements
  # Who a notice of the board reaches (RN-15-071, CA-15-011, D-656): everyone, or the people
  # with an open employment whose current revision is in one of the units, departments and
  # positions chosen, and of one of the employment kinds chosen. Inside a list any value
  # counts; between lists, all of them. It is read when someone opens the board, so who joins
  # later sees it while it is in force (D-656). The same rule answers both ways: the people of
  # a notice (profiles) and the notices of a person (Announcement.reaching).
  class Audience
    LISTS = %w[unit_ids department_ids position_ids employment_kinds].freeze
    # The value of a person's place each list is compared with.
    COLUMNS = { "unit_ids" => :unit_id, "department_ids" => :department_id, "position_ids" => :position_id,
      "employment_kinds" => :kind }.freeze

    attr_reader :filter

    def initialize(filter)
      filter = filter.to_h.stringify_keys
      @filter = LISTS.to_h { |key| [ key, Array(filter[key]).map(&:to_s).compact_blank.uniq.sort ] }.select { |_key, values| values.any? }
    end

    def everyone?
      filter.empty?
    end

    def unit_ids
      filter["unit_ids"] || []
    end

    # The people it reaches now.
    def profiles
      revisions = EmploymentRevision.counting.where(employment_id: Employment.open.select(:id))
      %w[unit_ids department_ids position_ids].each do |key|
        revisions = revisions.where(COLUMNS[key] => filter[key]) if filter[key]
      end
      employments = Employment.open.where(id: revisions.select(:employment_id))
      employments = employments.where(kind: filter["employment_kinds"]) if filter["employment_kinds"]
      WorkerProfile.where(id: employments.select(:worker_profile_id))
    end

    # The people it reaches who can open the portal: the ones that count for the reads.
    def members
      profiles.where(membership_id: Membership.active.select(:id))
    end

    # Where each open employment of the person is today: the values a notice's lists are
    # compared with.
    def self.places(profile)
      employments = Employment.open.where(worker_profile: profile)
      EmploymentRevision.counting.where(employment_id: employments.select(:id))
        .joins("JOIN employments ON employments.id = employment_revisions.employment_id")
        .pluck("employment_revisions.unit_id", "employment_revisions.department_id", "employment_revisions.position_id", "employments.kind")
        .map { |unit_id, department_id, position_id, kind| { unit_id: unit_id, department_id: department_id, position_id: position_id, kind: kind } }
    end
  end
end

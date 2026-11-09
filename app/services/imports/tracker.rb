module Imports
  # What one confirmed line did to the company (RN-18-052, D-665): the records it created and,
  # for each one it changed, the values before. Sensitive fields included, since PaperTrail
  # leaves them out (D-086): the list is kept encrypted on the row and leaves with its data
  # after 90 days (RN-18-010). "at" is the record's updated_at after the change, to tell
  # whether someone changed it later.
  class Tracker
    # The trail and the counters stay as they are: undoing never erases an audit record, and
    # a registration number once suggested is not given back.
    IGNORED = %w[AccessEvent ActivityEvent Company DataImport DataImportRow FeatureFlagChange ProcessEvent].freeze

    attr_reader :entries

    def self.current = Current.import_tracker

    # Runs the block with a tracker and returns what it recorded.
    def self.track
      previous = Current.import_tracker
      tracker = new
      Current.import_tracker = tracker
      yield
      tracker.entries
    ensure
      Current.import_tracker = previous
    end

    def initialize
      @entries = []
    end

    def created(record)
      add(record, "create")
    end

    def updated(record)
      changes = record.saved_changes.except("updated_at", "created_at")
      add(record, "update", "before" => changes.transform_values(&:first)) if changes.any?
    end

    # The imports never delete; a line that did is not undone.
    def destroyed(record)
      add(record, "destroy")
    end

    private

    def add(record, op, extra = {})
      return if IGNORED.include?(record.class.name)

      @entries << { "op" => op, "type" => record.class.name, "id" => record.id,
        "at" => record.try(:updated_at)&.utc&.iso8601(6) }.merge(extra).as_json
    end
  end
end

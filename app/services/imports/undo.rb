module Imports
  # Undoes a whole import while nothing of it was used (RN-18-050 to RN-18-052, D-465, D-665):
  # from the last line back, the records it changed get their values before, including the
  # sensitive ones PaperTrail leaves out (D-086), and the records it created are deleted, even
  # an employment or a revision in force (D-603 does not hold here). All or nothing, in one
  # transaction, in the trail with the origin "undo:<id>".
  #
  # What blocks (RN-18-051): an accepted invitation; a record of the import changed later; a
  # record created later that points to one the import created (a dependent, an account, a
  # revision, a manager, a document, an admission...). The list says which and why.
  class Undo
    UNDOABLE = %w[completed completed_with_errors].freeze
    MAX_BLOCKERS = 100

    # Only an import recorded with what each line did (marked at the end of the recording),
    # still within the 90 days (RN-18-010).
    def self.available?(import)
      import.status.in?(UNDOABLE) && import.purged_at.nil? && import.options["undoable"] == true
    end

    def initialize(import, by:)
      @import = import
      @by = by
    end

    # Undoes, or returns what blocks.
    def call
      entries = self.class.entries(@import)
      blockers = Check.new(entries).blockers
      return blockers if blockers.any?

      Current.import_undo = true
      PaperTrail.request(whodunnit: @by.id, controller_info: { request_id: "undo:#{@import.id}" }) do
        ActiveRecord::Base.transaction do
          entries.reverse_each { |entry| revert(entry) }
          @import.update!(status: "undone", undone_at: Time.current, undone_by: @by, undo_blockers: nil)
        end
      end
      []
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError => error
      [ { "record" => nil, "message" => I18n.t("imports.undo.blockers.linked", kind: error.class.name.demodulize) } ]
    ensure
      Current.import_undo = nil
    end

    # Every line's changes, in the order they were recorded.
    def self.entries(import)
      import.rows.status_imported.to_a.sort_by { |row| row.undo_data["sequence"] }.flat_map { |row| row.undo_data["entries"] }
    end

    private

    def revert(entry)
      record = Check.find(entry)
      return if record.nil?

      if entry["op"] == "create"
        record.destroy!
      else
        record.assign_attributes(entry["before"])
        record.save!(validate: false)
      end
    end

    # What keeps the import from being undone.
    class Check
      IGNORED_ASSOCIATIONS = %w[PaperTrail::Version ActiveStorage::Attachment ActiveStorage::Blob].freeze

      def self.find(entry)
        model = entry["type"].safe_constantize
        model&.find_by(id: entry["id"])
      end

      def initialize(entries)
        @created = entries.select { |entry| entry["op"] == "create" }.group_by { |entry| entry["type"] }
          .transform_values { |list| list.to_set { |entry| entry["id"] } }
        # The last time the import touched each record, and the first.
        @touched = entries.each_with_object({}) { |entry, last| last[[ entry["type"], entry["id"] ]] = entry }
        @first = entries.reverse.each_with_object({}) { |entry, first| first[[ entry["type"], entry["id"] ]] = entry }
      end

      def blockers
        list = []
        @touched.each_value do |entry|
          record = self.class.find(entry)
          if record.nil?
            list << blocker(nil, :missing, model: entry["type"].safe_constantize&.model_name&.human) unless entry["op"] == "create" && created?(entry)
            next
          end

          if record.is_a?(Membership) && record.active? && invited_by_import?(entry)
            list << blocker(record, :invitation_accepted)
          elsif changed_later?(record, entry)
            list << blocker(record, :changed_later)
          end
          used_by(record).each { |model| list << blocker(record, :used_by, what: model.model_name.human) } if created?(entry)
          break if list.size >= MAX_BLOCKERS
        end
        list.uniq.first(MAX_BLOCKERS)
      end

      private

      def created?(entry)
        @created.fetch(entry["type"], Set.new).include?(entry["id"])
      end

      # A membership the import created, or whose status it changed, now active: the person
      # accepted the invitation (RN-18-050).
      def invited_by_import?(entry)
        first = @first[[ entry["type"], entry["id"] ]]
        created?(entry) || first.dig("before", "status").present?
      end

      def changed_later?(record, entry)
        stamp = record.try(:updated_at)
        stamp && entry["at"] && stamp.utc > Time.iso8601(entry["at"]) + 0.000001
      end

      # The models with records pointing to this one that the import did not create: every
      # belongs_to of the application aimed at its class, polymorphic ones included, whether
      # or not the class declares the has_many.
      def used_by(record)
        direct, polymorphic = self.class.references
        candidates = direct.fetch(record.class.name, []) + polymorphic
        candidates.filter_map do |model, foreign_key, type_column|
          scope = model.unscoped.where(foreign_key => record.id).where.not(model.primary_key => @created.fetch(model.name, Set.new).to_a)
          scope = scope.where(type_column => record.class.name) if type_column
          model if scope.exists?
        end.uniq
      end

      # The belongs_to of every model: by the class they point to, and the polymorphic ones.
      def self.references
        @references ||= begin
          Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/models").to_s)
          direct = Hash.new { |hash, key| hash[key] = [] }
          polymorphic = []
          ApplicationRecord.descendants.reject(&:abstract_class?).each do |model|
            next if IGNORED_ASSOCIATIONS.include?(model.name) || Tracker::IGNORED.include?(model.name)

            model.reflect_on_all_associations(:belongs_to).each do |reflection|
              if reflection.polymorphic?
                polymorphic << [ model, reflection.foreign_key.to_s, reflection.foreign_type.to_s ]
              else
                direct[reflection.class_name.delete_prefix("::")] << [ model, reflection.foreign_key.to_s, nil ]
              end
            end
          end
          [ direct.to_h, polymorphic ].freeze
        end
      end

      def blocker(record, key, **details)
        { "record" => record && describe(record), "message" => I18n.t("imports.undo.blockers.#{key}", **details) }
      end

      def describe(record)
        case record
        when User then record.name
        when Membership then record.user.name
        when WorkerProfile then record.user.name
        when Employment then I18n.t("imports.undo.employment", number: record.registration_number, name: record.worker_profile.user.name)
        else
          label = record.try(:code) || record.try(:name) || record.try(:registration_number)
          [ record.model_name.human, label ].compact.join(" ")
        end
      end
    end
  end
end

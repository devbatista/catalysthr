module Ai
  # What the review shows of a version's reading (spec 14, RN-14-022 to RN-14-024, RN-08-021,
  # CA-14-001, CA-14-002): each field read beside the record, marked "confere", "divergência" or
  # "campo novo", with the system's objective checks (the CPF's and the PIS's digits, the CEP,
  # the validity and the age of the document, the other approved documents of the person), the
  # visual signs as alerts and what the review's own fields start with. The AI checks nothing
  # here: it only read (P-14-08).
  class ExtractionReview
    Row = Data.define(:field, :value, :record_value, :status, :confidence, :page, :issues) do
      def applicable? = field.apply.present? && value.present? && status.in?(%i[new divergent])
      def sensitive? = field.apply.in?(WorkerProfile::DOCUMENT_FIELDS)
      def low_confidence? = confidence == "low"
    end
    Alert = Data.define(:key, :params)

    COMPARED_WITH_OTHERS = %w[name cpf birth_date].freeze

    attr_reader :extraction

    def initialize(version)
      @version = version
      @document = version.document
      @profile = @document.worker_profile
      @user = @profile.user
      @extraction = AiExtraction.find_by(subject: version)
    end

    def read? = extraction&.succeeded? || false

    def rows
      return [] unless read?

      @rows ||= ExtractionProfiles.fields(extraction.profile_code).map do |field|
        read = extraction.field(field.key) || {}
        value = read["value"]
        record = record_value(field)
        Row.new(field: field, value: value, record_value: record, status: status(field, value, record),
          confidence: read["confidence"], page: read["page"], issues: issues(field, value))
      end
    end

    def alerts
      return [] unless read?

      list = []
      if extraction.detected_type_code != extraction.profile_code || extraction.flags.include?("wrong_type")
        list << Alert.new(:wrong_type, { detected: detected_name })
      end
      (extraction.flags - %w[wrong_type]).each { |flag| list << Alert.new(:"flag_#{flag}", {}) }
      list + other_documents
    end

    # The review's own fields, from what was read (the HR confirms on approving).
    def prefill
      rows.select { |row| row.field.prefill && row.value.present? }.to_h { |row| [ row.field.prefill, row.value ] }
    end

    private

    def record_value(field)
      value = case field.compare || field.apply
      when :user_name then @user.name
      when :user_cpf then @user.cpf
      when :user_birth_date then @user.birth_date
      when nil then nil
      else @profile.public_send(field.apply)
      end
      value.respond_to?(:iso8601) ? value.iso8601 : value.presence
    end

    def status(field, value, record)
      return :shown unless field.compare || field.apply
      return :missing if value.blank?
      return field.apply ? :new : :no_record if record.blank?

      same?(value, record) ? :matches : :divergent
    end

    def same?(read, record) = comparable(read) == comparable(record)

    def comparable(value) = I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]/, "")

    def issues(field, value)
      return [] if value.blank?

      list = []
      list << :invalid_cpf if field.kind == :cpf && !Cpf.valid?(value)
      list << :invalid_pis if field.kind == :pis && !Pis.valid?(value)
      list << :postal_code_not_found if field.kind == :postal_code && extraction.checks["postal_code"] == "not_found"
      list << :expired if field.prefill == :valid_until && Date.iso8601(value) < @profile.today
      list << :too_old if field.prefill == :issued_on && too_old?(value)
      list
    end

    def too_old?(value)
      Documents::Expiration.too_old?(@document.document_type, Date.iso8601(value), @profile.today)
    end

    # The name, the CPF and the birth date against what was read from the person's other
    # approved documents (RN-14-022).
    def other_documents
      mine = rows.select { |row| row.field.key.in?(COMPARED_WITH_OTHERS) && row.value.present? }.index_by { |row| row.field.key }
      return [] if mine.empty?

      approved = DocumentVersion.joins(:document).where(documents: { worker_profile_id: @profile.id, deleted_at: nil }, status: "approved")
        .where.not(id: @version.id).includes(document: :document_type)
      AiExtraction.succeeded.where(subject: approved).includes(:subject).filter_map do |other|
        diverging = mine.select { |key, row| (theirs = other.value(key)).present? && !same?(row.value, theirs) }.keys
        next if diverging.empty?

        Alert.new(:other_document, { type: other.subject.document.document_type.name,
          fields: diverging.map { |key| I18n.t("ai.extraction.fields.#{key}") }.to_sentence })
      end
    end

    def detected_name
      code = extraction.detected_type_code
      I18n.t("ai.extraction.profiles.#{code}", default: code.to_s)
    end
  end
end

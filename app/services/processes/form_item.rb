module Processes
  # A form item from the answers to the record (RN-06-010, RN-06-030, RN-06-031, D-649):
  # saved as a draft, sent to the HR, given back with a reason or applied. Nothing reaches
  # the record before the HR applies it. Applying checks everything with the record's own
  # rules, adds the rows and keeps only the free fields, with the names of what went to the
  # record (D-649). Each step goes to the history, without values (RN-06-051). Returns false
  # with the messages in #errors.
  class FormItem
    EDITABLE = %w[pending correction_requested].freeze
    APPLICABLE = %w[pending submitted correction_requested].freeze

    attr_reader :errors, :schema

    def initialize(item, by:)
      @item = item
      @by = by
      @schema = FormSchema.new(item)
      @errors = []
    end

    def response
      @response ||= @item.form_response || @item.build_form_response
    end

    def save(params)
      return closed unless @item.instance.open? && @item.status.in?(APPLICABLE)

      store(params)
      true
    end

    # By the employee in the portal: it goes to the HR's review.
    def submit(params)
      @item.with_lock do
        next closed unless @item.instance.open? && @item.status.in?(EDITABLE)

        store(params)
        next false unless checked?

        response.update!(submitted_at: Time.current, submitted_by: @by, correction_reason: nil)
        @item.update!(status: "submitted")
        Events.record(@item.instance, "form_submitted", by: @by, item: @item, title: @item.title)
        true
      end.tap { |done| Notices.form_submitted(@item) if done }
    end

    # Back to the person, with a reason they see (D-649).
    def give_back(reason:)
      reason = reason.to_s.strip.presence
      return failed(I18n.t("processes.form.reason_blank")) unless reason

      @item.with_lock do
        next closed unless @item.instance.open? && @item.submitted?

        response.update!(correction_reason: reason)
        @item.update!(status: "correction_requested")
        Events.record(@item.instance, "form_returned", by: @by, item: @item, title: @item.title, reason: reason)
        true
      end.tap { |done| Notices.form_returned(@item) if done }
    end

    def apply(params = nil)
      done = @item.with_lock do
        next closed unless @item.instance.open? && @item.status.in?(APPLICABLE)

        store(params) if params
        next false unless checked?

        fields = write_to_record
        response.update!(answers: response.data.slice("free"), applied_at: Time.current, applied_by: @by, applied_fields: fields)
        @item.update!(status: "done", completed_by: @by, completed_at: Time.current, result: { "applied" => fields.size })
        Events.record(@item.instance, "form_applied", by: @by, item: @item, title: @item.title)
        true
      end
      return false unless done

      AccessEvent.record!(kind: "admin", action: "form_applied", user: @by, subject: @item)
      UnblockItemsJob.perform_later(@item)
      true
    rescue ActiveRecord::RecordInvalid => error
      failed(error.record.errors.full_messages.to_sentence)
    end

    private

    def store(params)
      response.update!(answers: @schema.clean(params, response.data))
    end

    def profile_attributes
      response.data.fetch("fields", {})
    end

    def build_rows(profile)
      rows = response.data.fetch("rows", {})
      contacts = rows.fetch("emergency_contacts", []).map { |row| EmergencyContact.new(row.merge(worker_profile: profile)) }
      dependents = rows.fetch("dependents", []).map { |row| Dependent.new(row.merge(worker_profile: profile)) }
      contacts + dependents
    end

    def bank_attributes
      response.data["bank_account"]
    end

    # The record's own rules, on a copy, so the screen tells everything at once.
    def checked?
      profile = WorkerProfile.find(@schema.profile.id)
      profile.assign_attributes(profile_attributes)
      profile.custom_field_values = response.data.fetch("custom", {})
      @errors.concat(profile.errors.full_messages) unless profile.valid?
      build_rows(profile).reject(&:valid?).each { |row| @errors.concat(row.errors.full_messages) }
      if bank_attributes
        account = profile.bank_accounts.new(bank_attributes.merge(primary: true, declared_by: @by, declared_at: Time.current))
        @errors.concat(account.errors.full_messages) unless account.valid?
      end
      @errors.empty?
    end

    # The names of what went to the record, never the values (D-649).
    def write_to_record
      profile = @schema.profile
      profile.assign_attributes(profile_attributes)
      profile.custom_field_values = response.data.fetch("custom", {})
      profile.save!
      rows = build_rows(profile).each(&:save!)
      applied = profile_attributes.keys + response.data.fetch("custom", {}).keys.map { |key| "custom:#{key}" }
      applied += rows.map { |row| row.class.name.underscore }
      applied << "bank_account" if register_bank(profile)
      applied
    end

    def register_bank(profile)
      return false unless bank_attributes

      account = BankAccounts::Register.call(profile: profile, attributes: bank_attributes, primary: true, by: @by)
      raise ActiveRecord::RecordInvalid, account unless account.persisted?

      true
    end

    def closed
      failed(I18n.t("processes.form.closed"))
    end

    def failed(message)
      @errors << message
      false
    end
  end
end

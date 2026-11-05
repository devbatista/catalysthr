module Processes
  # What a form item asks (RN-06-030, D-649): the groups of the record, the custom fields and
  # the free fields chosen in the model. It tells each field's type and whether it's
  # sensitive, by the section whose display needs the password (RN-02-052); those never come
  # filled from the record (D-649). Read inside the company.
  class FormSchema
    Field = Data.define(:key, :type, :options, :section, :label) do
      def sensitive?
        !section.nil?
      end
    end

    LABELS = { "birth_state" => "state", "rg_state" => "state", "ctps_state" => "state", "rg_issued_on" => "issued_on",
      "disability_rehabilitated" => "rehabilitated" }.freeze
    OPTIONS = { "sex" => "sexes", "race" => "races", "marital_status" => "marital_statuses", "education_level" => "education_levels",
      "immigration_condition" => "immigration_conditions" }.freeze
    DATES = %w[rg_issued_on cnh_expires_on arrived_on].freeze
    BOOLEANS = %w[lives_abroad married_to_brazilian brazilian_children disability_rehabilitated].freeze
    STATES = %w[birth_state rg_state ctps_state state].freeze
    GROUPS = {
      "identification" => %w[social_name sex race marital_status education_level],
      "birth" => %w[birth_city birth_state birth_country nationality],
      "documents" => %w[rg_number rg_issuer rg_state rg_issued_on ctps_number ctps_series ctps_state pis_nis voter_id cnh_number
        cnh_category cnh_expires_on class_registration class_registration_issuer foreign_registration],
      "address" => %w[lives_abroad postal_code street street_number complement district city state ibge_city_code foreign_country
        foreign_address],
      "foreigner" => %w[arrived_on immigration_condition married_to_brazilian brazilian_children],
      "disability" => %w[disability_types disability_rehabilitated disability_notes],
      "contact" => %w[personal_email personal_phone]
    }.freeze
    ROWS = {
      "emergency_contacts" => %w[name relationship phone],
      "dependents" => %w[name relationship_type birth_date cpf sex irrf family_allowance incapable]
    }.freeze
    BANK = %w[bank_code branch account_number account_type pix_key_type pix_key].freeze
    MAX_ROWS = 10

    attr_reader :item, :profile

    def initialize(item)
      @item = item
      @profile = item.instance.employment.worker_profile
      @groups = item.config.fetch("groups", [])
    end

    def sections
      (GROUPS.keys & @groups).map { |group| [ group, GROUPS.fetch(group).map { |key| field(key) } ] }
    end

    def fields
      sections.flat_map(&:last)
    end

    def row_groups
      ROWS.keys & @groups
    end

    def bank?
      @groups.include?("bank_account")
    end

    def custom_fields
      @custom_fields ||= CustomFieldDefinition.active.where(key: item.config.fetch("custom_field_keys", [])).ordered.to_a
    end

    def free_fields
      item.config.fetch("free_fields", [])
    end

    # The sections whose values this form shows: the password and the permissions depend on them.
    def needed_sections
      needed = fields.filter_map(&:section)
      needed << "documents" if row_groups.include?("dependents")
      needed << "pay" if bank?
      needed.uniq
    end

    # What the form saves: only the keys it asks. A sensitive field left blank keeps the value
    # already answered, because it never comes back to the screen filled in the portal.
    def clean(params, previous)
      params = params.to_h.deep_stringify_keys
      old = previous || {}
      values = fields.to_h { |field| [ field.key, field_value(field, params.dig("fields", field.key), old.dig("fields", field.key)) ] }
      # An unchecked box counts only where it comes filled: a sensitive one never overwrites.
      unchecked = values.select { |key, value| value == false && fields.find { |field| field.key == key }.section.nil? }
      { "fields" => values.compact_blank.merge(unchecked),
        "custom" => params.fetch("custom", {}).slice(*custom_fields.map(&:key)).compact_blank,
        "free" => params.fetch("free", {}).slice(*free_fields).transform_values { |text| text.to_s.strip.first(2000) }.compact_blank,
        "rows" => row_groups.to_h { |group| [ group, rows(group, params.dig("rows", group), old.dig("rows", group)) ] },
        "bank_account" => bank(params["bank_account"], old["bank_account"]) }.compact_blank
    end

    private

    def field(key)
      section = if key.start_with?("disability") then "health"
      elsif WorkerProfile::DOCUMENT_FIELDS.include?(key.to_sym) then "documents"
      end
      type, options = type_of(key)
      Field.new(key: key, type: type, options: options, section: section, label: LABELS.fetch(key, key))
    end

    def type_of(key)
      if key == "disability_types" then [ :disability_types, WorkerProfile::DISABILITY_TYPES ]
      elsif key == "cnh_category" then [ :plain_select, WorkerProfile::CNH_CATEGORIES ]
      elsif OPTIONS.key?(key) then [ :select, WorkerProfile.const_get(OPTIONS.fetch(key).upcase) ]
      elsif STATES.include?(key) then [ :plain_select, Unit::STATES ]
      elsif DATES.include?(key) then [ :date, nil ]
      elsif BOOLEANS.include?(key) then [ :boolean, nil ]
      elsif key == "disability_notes" then [ :text_area, nil ]
      elsif key == "personal_email" then [ :email, nil ]
      elsif key == "personal_phone" then [ :tel, nil ]
      else [ :text, nil ]
      end
    end

    def field_value(field, value, old)
      case field.type
      when :boolean then value.nil? ? old : ActiveModel::Type::Boolean.new.cast(value)
      when :disability_types then value ? Array(value).compact_blank & field.options : old
      else
        text = value.to_s.strip
        text.empty? && field.sensitive? ? old : text
      end
    end

    # A row without a name is dropped; the sensitive CPF left blank keeps the one answered.
    def rows(group, params, previous)
      list = params.to_h.sort_by { |index, _row| index.to_i }.first(MAX_ROWS)
      list.filter_map do |index, row|
        kept = row.to_h.slice(*ROWS.fetch(group)).transform_values { |value| value.to_s.strip }
        next if kept["name"].blank?

        before = Array(previous)[index.to_i]
        kept["cpf"] = before["cpf"] if group == "dependents" && kept["cpf"].blank? && before.is_a?(Hash)
        kept.compact_blank
      end
    end

    def bank(params, previous)
      kept = params.to_h.slice(*BANK).transform_values { |value| value.to_s.strip }
      merged = previous.to_h.slice("account_number", "pix_key").merge(kept.compact_blank)
      merged.keys.intersect?(%w[bank_code branch account_number pix_key]) ? merged : nil
    end
  end
end

module Ai
  # The fields the AI reads from each platform type (spec 14, RN-14-021, P-14-07, D-670).
  #
  # Each field says how the system checks it (RN-14-022) and where it may go:
  # - `compare`: what it is compared with. The name, the CPF and the birth date are the
  #   person's (User), which serves every company and the sign-in, so they are only compared
  #   and never changed by the review (D-670);
  # - `apply`: the record's attribute the HR may fill with it, field by field (RN-08-021);
  # - `prefill`: the review's own field it fills (the validity, the issue date, the ASO's
  #   result), which the HR confirms on approving.
  # A field with neither only shows for the HR to check (D-670).
  module ExtractionProfiles
    Field = Data.define(:key, :kind, :compare, :apply, :prefill) do
      def initialize(key:, kind: :text, compare: nil, apply: nil, prefill: nil) = super
    end

    NAME = Field.new(key: "name", compare: :user_name)
    CPF = Field.new(key: "cpf", kind: :cpf, compare: :user_cpf)
    BIRTH = Field.new(key: "birth_date", kind: :date, compare: :user_birth_date)

    ALL = {
      "rg" => [
        NAME, Field.new(key: "rg_number", apply: :rg_number), Field.new(key: "rg_issuer", apply: :rg_issuer),
        Field.new(key: "rg_state", kind: :state, apply: :rg_state), Field.new(key: "rg_issued_on", kind: :date, apply: :rg_issued_on),
        BIRTH, Field.new(key: "filiation"), Field.new(key: "birth_city", apply: :birth_city),
        Field.new(key: "birth_state", kind: :state, apply: :birth_state), CPF
      ],
      "cpf" => [ CPF, NAME, BIRTH ],
      "cnh" => [
        NAME, CPF, Field.new(key: "cnh_number", apply: :cnh_number), Field.new(key: "cnh_category", kind: :cnh_category, apply: :cnh_category),
        Field.new(key: "issued_on", kind: :date), Field.new(key: "valid_until", kind: :date, apply: :cnh_expires_on, prefill: :valid_until),
        Field.new(key: "first_license_on", kind: :date), BIRTH
      ],
      "ctps_pis" => [ NAME, CPF, Field.new(key: "pis_nis", kind: :pis, apply: :pis_nis) ],
      "proof_of_address" => [
        Field.new(key: "holder_name", compare: :user_name), Field.new(key: "street", apply: :street),
        Field.new(key: "street_number", apply: :street_number), Field.new(key: "complement", apply: :complement),
        Field.new(key: "district", apply: :district), Field.new(key: "city", apply: :city),
        Field.new(key: "state", kind: :state, apply: :state), Field.new(key: "postal_code", kind: :postal_code, apply: :postal_code),
        Field.new(key: "issued_on", kind: :date, prefill: :issued_on)
      ],
      "certificate" => [
        Field.new(key: "certificate_kind"), Field.new(key: "names"), Field.new(key: "event_date", kind: :date),
        Field.new(key: "registration")
      ],
      "aso" => [
        NAME, CPF, Field.new(key: "exam_type"), Field.new(key: "aso_result", kind: :aso_result, prefill: :aso_result),
        Field.new(key: "exam_on", kind: :date, prefill: :issued_on), Field.new(key: "physician"), Field.new(key: "crm")
      ],
      "medical_certificate" => [
        NAME, Field.new(key: "starts_on", kind: :date), Field.new(key: "days"), Field.new(key: "ends_on", kind: :date),
        Field.new(key: "cid"), Field.new(key: "physician"), Field.new(key: "crm")
      ]
    }.freeze

    # The record's attributes the review may fill, never the person's name, CPF or birth date.
    APPLICABLE = ALL.values.flatten.filter_map(&:apply).uniq.freeze

    module_function

    def codes = ALL.keys
    def fields(code) = ALL.fetch(code.to_s)
    def keys = all_fields.map(&:key)
    def all_fields = ALL.values.flatten.uniq(&:key)
  end
end

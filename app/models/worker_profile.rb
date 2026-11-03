# The person's record in a company (RN-04-040 to RN-04-042, P-04-01, D-209): one per
# company membership, never read by another company (CA-04-007). The civil name, CPF,
# birth date and the sign-in contacts stay in the User (P-04-03).
#
# The groups follow the eSocial worker's data (D-206). List fields keep the system's own
# values; the matching eSocial codes, and the final list itself, come with spec 13
# (P-04-15, D-602). Personal documents and the disability are sensitive (D-086): they
# are encrypted and stay out of the versions.
class WorkerProfile < ApplicationRecord
  SEXES = %w[female male].freeze
  RACES = %w[white black brown yellow indigenous not_informed].freeze
  MARITAL_STATUSES = %w[single married divorced separated widowed].freeze
  EDUCATION_LEVELS = %w[
    illiterate elementary_early_incomplete elementary_early elementary_late_incomplete elementary
    high_school_incomplete high_school higher_incomplete higher postgraduate masters doctorate
  ].freeze
  CNH_CATEGORIES = %w[A B C D E AB AC AD AE].freeze
  IMMIGRATION_CONDITIONS = %w[
    refugee refugee_applicant family_reunion mercosur_agreement diplomatic_dependent brazil_portugal_treaty other
  ].freeze
  DISABILITY_TYPES = %w[physical visual hearing mental intellectual].freeze
  # Sensitive fields, by the group whose display needs the password (RN-02-052).
  DOCUMENT_FIELDS = %i[rg_number ctps_number pis_nis voter_id cnh_number class_registration foreign_registration].freeze
  HEALTH_FIELDS = %i[disability].freeze

  audited sensitive: DOCUMENT_FIELDS + HEALTH_FIELDS

  acts_as_tenant :company

  belongs_to :membership
  has_one :user, through: :membership
  has_many :employments, dependent: :restrict_with_error
  has_many :emergency_contacts, dependent: :restrict_with_error
  has_many :dependents, dependent: :restrict_with_error
  has_many :bank_accounts, dependent: :restrict_with_error

  encrypts(*DOCUMENT_FIELDS)
  serialize :disability, coder: JSON
  encrypts :disability

  enum :sex, SEXES.index_by(&:itself), validate: { allow_nil: true }, prefix: true
  enum :race, RACES.index_by(&:itself), validate: { allow_nil: true }, prefix: true
  enum :marital_status, MARITAL_STATUSES.index_by(&:itself), validate: { allow_nil: true }, prefix: true
  enum :education_level, EDUCATION_LEVELS.index_by(&:itself), validate: { allow_nil: true }, prefix: true
  enum :immigration_condition, IMMIGRATION_CONDITIONS.index_by(&:itself), validate: { allow_nil: true }, prefix: true

  normalizes :postal_code, :pis_nis, :ibge_city_code, :personal_phone, with: ->(value) { value.to_s.gsub(/\D/, "").presence }
  normalizes :rg_number, :ctps_number, :voter_id, :cnh_number, :foreign_registration,
    with: ->(value) { value.to_s.gsub(/[^0-9A-Za-z]/, "").upcase.presence }
  normalizes :state, :birth_state, :rg_state, :ctps_state, :cnh_category, with: ->(value) { value.to_s.strip.upcase.presence }
  normalizes :personal_email, with: ->(email) { email.to_s.strip.downcase.presence }
  normalizes :social_name, :class_registration, :class_registration_issuer, :rg_issuer, :birth_city, :birth_country,
    :nationality, :street, :street_number, :complement, :district, :city, :foreign_country,
    with: ->(value) { value.to_s.squish.presence }

  validates :membership_id, uniqueness: true
  validates :social_name, length: { maximum: 120 }
  validates :state, :birth_state, :rg_state, :ctps_state, inclusion: { in: Unit::STATES }, allow_nil: true
  validates :cnh_category, inclusion: { in: CNH_CATEGORIES }, allow_nil: true
  validates :postal_code, format: { with: Unit::POSTAL_CODE_FORMAT }, allow_nil: true
  validates :pis_nis, format: { with: /\A\d{11}\z/ }, allow_nil: true
  validates :ibge_city_code, format: { with: /\A\d{7}\z/ }, allow_nil: true
  validates :personal_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :foreign_country, presence: true, if: :lives_abroad?
  validate :membership_of_company
  validate :disability_types_known
  validate :custom_fields_valid
  validate :required_custom_fields, on: :record_edit

  def audit_company_id
    company_id
  end

  # The U scope (D-142): people with an employment whose current revision is in one of
  # the units; a past employment counts by its last unit.
  def self.in_units(unit_ids)
    employment_ids = EmploymentRevision.counting.where(unit_id: unit_ids).select(:employment_id)
    where(id: Employment.where(id: employment_ids).select(:worker_profile_id))
  end

  # The E scope (RN-04-022, D-190): people with an open employment in one of the
  # departments.
  def self.in_departments(department_ids)
    employment_ids = EmploymentRevision.counting.where(department_id: department_ids).select(:employment_id)
    where(id: Employment.open.where(id: employment_ids).select(:worker_profile_id))
  end

  # The K scope (RN-04-095, D-570): people with an open employment whose current revision,
  # or the first one before the start, points to one of the clients.
  def self.in_allocation_clients(client_ids)
    employment_ids = EmploymentRevision.counting.where(allocation_client_id: client_ids).select(:employment_id)
    where(id: Employment.open.where(id: employment_ids).select(:worker_profile_id))
  end

  # The values typed for the company's active custom fields (RN-04-080, RN-04-081). A
  # field left out keeps its value; the values of inactive fields stay as they are.
  def custom_field_values=(values)
    values = values.to_h.stringify_keys
    @invalid_custom_fields = []
    data = custom_fields.to_h.dup
    CustomFieldDefinition.active.each do |definition|
      next unless values.key?(definition.key)

      value = definition.cast(values[definition.key])
      if value == :invalid
        @invalid_custom_fields << definition
      elsif value.nil?
        data.delete(definition.key)
      else
        data[definition.key] = value
      end
    end
    self.custom_fields = data
  end

  def custom_field_value(definition)
    custom_fields.to_h[definition.key]
  end

  # Required fields still empty, shown as a warning; the record saved by the HR must fill
  # them (D-605).
  def missing_custom_fields
    CustomFieldDefinition.active.where(required: true).ordered.reject { |definition| !custom_field_value(definition).nil? }
  end

  # The name used with the person: the social name, when there is one.
  def display_name
    social_name || user.name
  end

  # The employment that counts now: an open one, the newest first, or the last one.
  def current_employment
    employments.max_by { |employment| [ employment.open? ? 1 : 0, employment.started_on ] }
  end

  # Where the person works now, and today there (the unit's time zone).
  def current_unit
    current_employment&.effective_revision&.unit
  end

  def today
    Time.find_zone(current_unit&.time_zone || "America/Sao_Paulo").today
  end

  def disability_types
    Array(disability_data["types"])
  end

  def disability_types=(types)
    write_disability("types" => Array(types).compact_blank.map(&:to_s))
  end

  def disability_rehabilitated
    disability_data["rehabilitated"] == true
  end

  def disability_rehabilitated=(value)
    write_disability("rehabilitated" => ActiveModel::Type::Boolean.new.cast(value) || false)
  end

  def disability_notes
    disability_data["notes"]
  end

  def disability_notes=(notes)
    write_disability("notes" => notes.to_s.strip.presence)
  end

  def disability?
    disability_types.any? || disability_rehabilitated
  end

  private

  def disability_data
    disability.is_a?(Hash) ? disability : {}
  end

  def write_disability(changes)
    data = disability_data.merge(changes).compact
    self.disability = data.values.any? { |value| value.present? && value != false } ? data : nil
  end

  def membership_of_company
    return if membership.nil?

    errors.add(:membership, :other_company) unless membership.organization_type == "Company" && membership.organization_id == company_id
  end

  def custom_fields_valid
    Array(@invalid_custom_fields).each { |definition| errors.add(:base, :custom_field_invalid, label: definition.label) }
  end

  def required_custom_fields
    missing_custom_fields.each { |definition| errors.add(:base, :custom_field_required, label: definition.label) }
  end

  def disability_types_known
    errors.add(:disability_types, :inclusion) if (disability_types - DISABILITY_TYPES).any?
  end
end
